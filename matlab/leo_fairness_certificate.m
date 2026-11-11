function result = leo_fairness_certificate(report,overrides)
%LEO_FAIRNESS_CERTIFICATE V12原模型未封顶max-min的全域上下界，独立于被测搜索。
if nargin<2, overrides=struct(); end
o=struct('maxSeconds',180,'maxNodes',128,'maxIterations',150,'maxSimplexPivots',10000, ...
    'maxBeams',18,'maxSubsets',200000,'maxTotalSubsets',1500000,'roundingCandidates',8, ...
    'recoverySeconds',.2,'relativeGap',1e-5,'absoluteGap',1e-6,'pricingTolerance',1e-8, ...
    'artificialPenalty',1000,'verbose',true,'relaxationMaxSeconds',30,'relaxationMaxIterations',150);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
for name={'maxSeconds','recoverySeconds','relativeGap','absoluteGap','relaxationMaxSeconds'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=0);
end
for name={'maxNodes','maxIterations','maxSimplexPivots','maxBeams','maxSubsets','maxTotalSubsets','roundingCandidates','relaxationMaxIterations'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=1 && v==fix(v));
end
assert(o.pricingTolerance>0 && o.artificialPenalty>0);
data=report.problemData; assert(leo_is_lexicographic(data),'The V12 fairness certificate requires the uncapped objective.');
K=data.shape(1); M=data.shape(2); started=tic; budget=struct('timer',started,'seconds',o.maxSeconds);
bestX=false(K,M); best=leo_evaluate_service(data,bestX);
pool.groups=cell(1,M); pool.service=cell(1,M);
for m=1:M, pool.groups{m}=false(K,0); pool.service{m}=zeros(K,0); end
schedules={bestX};
for j=1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed') || isempty(report.solutions{j}), continue; end
    if isfield(report.solutions{j},'stage1'), schedules{end+1}=report.solutions{j}.stage1.x; end %#ok<AGROW>
    schedules{end+1}=report.solutions{j}.x; %#ok<AGROW>
end
for j=1:numel(schedules)
    service=leo_evaluate_service(data,schedules{j});
    if leo_service_is_better(service,best,'fairness',0), best=service; bestX=schedules{j}; end
    for m=1:M
        group=logical(schedules{j}(:,m));
        if ~isempty(pool.groups{m}) && any(all(bsxfun(@eq,pool.groups{m},group),1)), continue; end
        pool.groups{m}(:,end+1)=group; pool.service{m}(:,end+1)=leo_resource_service(data,m,group)/1e6;
    end
end
limit=leo_fairness_limit(data); upper=limit; result=struct('lower',best.fairness,'upper',upper, ...
    'incumbentX',bestX,'incumbentService',best,'objectiveMode','lexicographic_max_min', ...
    'nodesProcessed',0,'openNodeCount',1,'pricingComplete',false,'branchTrace',struct([]), ...
    'options',o,'status','time_limit','scope','ORIGINAL uncapped max-min G/q; certificate search is separate from benchmark methods.');
result.problemDataSnapshot=data;
result=leo_strengthen_fairness_certificate(report,result,min(o.relaxationMaxSeconds,max(0,o.maxSeconds-toc(started))),o.relaxationMaxIterations);
upper=result.upper;
cache=leo_prepare_pricing_cache(data,o,budget); result.pricingComplete=cache.complete;
root=struct('fixed',-ones(K,M,'int8'),'pool',pool,'upper',upper,'id',1,'parent',0);
open={root}; nextId=2; closedUpper=0;
if cache.complete
    while ~isempty(open)
        upper=max([best.fairness,closedUpper,cellfun(@(n)n.upper,open)]);
        if met(upper,best.fairness,o), result.status='gap_target_met'; break; end
        if toc(started)>=o.maxSeconds, result.status='time_limit'; break; end
        if result.nodesProcessed>=o.maxNodes, result.status='node_limit'; break; end
        [~,j]=max(cellfun(@(n)n.upper,open)); task=open{j}; open(j)=[];
        if task.upper<=best.fairness, closedUpper=max(closedUpper,task.upper); continue; end
        node=leo_refine_fairness_node(data,cache,task.fixed,task.pool,task.upper,o,budget);
        result.nodesProcessed=result.nodesProcessed+1;
        candidates=node.roundedCandidates;
        for j=1:numel(candidates)
            candidate=candidates{j}; service=leo_evaluate_service(data,candidate);
            if toc(started)<o.maxSeconds && o.recoverySeconds>0
                problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
                localBudget=budget; localBudget.seconds=min(o.maxSeconds,toc(started)+o.recoverySeconds);
                options=leo_method_options(struct('recoveryEvaluations',160,'recoveryPasses',2,'verbose',false));
                recovered=leo_recover_schedule(problem,candidate,'fairness',0,options,task.id,localBudget);
                if leo_service_is_better(recovered.service,service,'fairness',0), candidate=recovered.x; service=recovered.service; end
            end
            if leo_service_is_better(service,best,'fairness',0), best=service; bestX=candidate; end
        end
        free=task.fixed==-1; decision=0; closed=false;
        if node.hardInfeasible
            closed=true;
        elseif node.upper<=best.fairness
            closed=true; closedUpper=max(closedUpper,node.upper);
        elseif ~any(free(:))
            candidate=task.fixed==1; service=leo_evaluate_service(data,candidate);
            if leo_service_is_better(service,best,'fairness',0), best=service; bestX=candidate; end
            closedUpper=max(closedUpper,service.fairness); closed=true;
        elseif toc(started)>=o.maxSeconds
            task.upper=node.upper; task.pool=node.pool; open{end+1}=task;
        else
            fraction=zeros(K,M);
            if ~isempty(node.fractionalX), fraction=min(node.fractionalX,1-node.fractionalX); end
            fraction(~free)=-Inf; [score,decision]=max(fraction(:));
            if score<1e-7, decision=find(free,1,'first'); end
            for value=0:1
                child=task; child.fixed(decision)=value; child.upper=node.upper; child.pool=node.pool;
                child.parent=task.id; child.id=nextId; nextId=nextId+1; open{end+1}=child;
            end
        end
        upper=max([best.fairness,closedUpper,cellfun(@(n)n.upper,open)]);
        row=struct('node',task.id,'parent',task.parent,'fairnessLower',best.fairness,'fairnessUpper',upper, ...
            'nodeUpper',node.upper,'openNodes',numel(open),'closed',closed,'branchVariable',decision, ...
            'pricingStatus',node.status,'pricingRounds',node.rounds);
        result.branchTrace=leo_append_struct(result.branchTrace,row);
        if o.verbose, fprintf('V12 fairness node %d: s in [%.9g, %.9g], open=%d, %s\n',task.id,best.fairness,upper,numel(open),node.status); end
    end
    if isempty(open), result.status='all_nodes_closed'; upper=max(best.fairness,closedUpper); end
elseif limit==0
    result.status='zero_fairness_bound';
else
    result.status=cache.status;
end
assert(upper>=best.fairness-1e-8*max(1,abs(upper)),'Fairness upper bound is below an original-model feasible schedule.');
result.lower=best.fairness; result.upper=max(upper,best.fairness); result.incumbentX=bestX; result.incumbentService=best;
result.absoluteGap=max(0,result.upper-result.lower); result.relativeGap=result.absoluteGap/max(result.upper,eps);
result.gapTargetMet=met(result.upper,result.lower,o); result.openNodeCount=numel(open); result.elapsedSeconds=toc(started);
result.problemDataSnapshot=data;
if result.upper<result.cardinalityRelaxation.upper
    result.upperBoundKind='Minimum of configuration LP dual and original integer refinement bounds';
end
end
function yes=met(upper,lower,o)
yes=upper-lower<=max(o.absoluteGap,o.relativeGap*max(upper,eps));
end
