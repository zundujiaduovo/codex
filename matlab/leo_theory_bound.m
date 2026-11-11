function result = leo_theory_bound(report,options)
%LEO_THEORY_BOUND 固定证书模型的列生成/分支定价：可行下界、全域上界与真实剩余差距。
% 不依赖外部优化工具箱。主问题的分数值不能冒充整数可行下界。
if nargin<2, options=struct(); end
if leo_is_lexicographic(report.problemData) && ~isfield(options,'fairnessFloor')
 error('leo:conditionalFloorRequired','V12 throughput bounds require an explicit fairnessFloor; use leo_fairness_certificate for stage 1.');
end
options=defaults(options); data=report.problemData; K=data.shape(1); M=data.shape(2);
if options.fairnessFloor~=1 || isfield(data,'certificateFairnessFloor'), data.certificateFairnessFloor=options.fairnessFloor; end
targets=leo_certificate_targets(data);
started=tic; budget=struct('timer',started,'seconds',options.maxSeconds);
result=struct('fairnessFloor',options.fairnessFloor,'userTargetsBits',targets, ...
 'lowerBits',NaN,'bestMethod','','bestSeed',NaN,'incumbentX',[], ...
 'recordServiceBits',NaN(numel(report.records),1),'recordFeasible',false(numel(report.records),1), ...
 'kind','UB1 cardinality relaxation','pricingComplete',false,'pricingIterations',0, ...
 'subsetCounts',zeros(1,M),'pricingStatus','','iterationTrace',struct([]),'blockTrace',struct([]), ...
 'branchTrace',struct([]),'nodesProcessed',0,'openNodeCount',1,'rootRelaxationUpperBits',NaN, ...
 'rootLPConverged',false,'targetRelativeGap',options.relativeGap,'targetAbsoluteGapBits',options.absoluteGapBits, ...
 'problemDataSnapshot',data,'minimumResourceCounts',[],'gapTargetMet',false,'infeasibilityCertified',false,'cappedServiceRelaxation',options.cappedService,'minimumCountCuts',options.countCuts,'lambda',zeros(K,1));
bestRecord=0;
for j=1:numel(report.records)
 if ~strcmp(report.records(j).status,'completed') || isempty(report.solutions{j}), continue; end
 s=leo_evaluate_service(data,report.solutions{j}.x);
 result.recordServiceBits(j)=s.totalBits; result.recordFeasible(j)=all(s.demandRatio>=options.fairnessFloor);
 if result.recordFeasible(j) && (isnan(result.lowerBits) || s.totalBits>result.lowerBits)
  result.lowerBits=s.totalBits; result.bestMethod=report.records(j).method;
  result.bestSeed=report.records(j).seed; result.incumbentX=report.solutions{j}.x; bestRecord=j;
 end
end
% 以前证书搜索发现的日程必须重新按本次原始评价器验收，才允许复用为下界。
if isfield(report,'theory') && isfield(report.theory,'incumbentX') && ~isempty(report.theory.incumbentX)
 try
  s=leo_evaluate_service(data,report.theory.incumbentX);
  if all(s.demandRatio>=options.fairnessFloor) && (isnan(result.lowerBits) || s.totalBits>result.lowerBits)
   result.lowerBits=s.totalBits; result.incumbentX=report.theory.incumbentX;
   result.bestMethod='previous_certificate_search'; result.bestSeed=NaN;
  end
 catch
  % 历史日程不属于本次可行域时不参与下界。
 end
end
coarse=leo_original_upper_bound(data,leo_prepare_upper_bounds(data),zeros(K,1),'throughput',options.fairnessFloor);
upper=coarse.value*data.referenceBits/1e6;
if isfield(report,'theory') && isfield(report.theory,'problemDataSnapshot') && ...
        isequaln(report.theory.problemDataSnapshot,data) && isfinite(report.theory.upperBits)
    upper=min(upper,report.theory.upperBits/1e6);
    result.kind='Previous matching-data certificate combined with UB1';
end
cache=leo_prepare_pricing_cache(data,options,budget);
if options.fairnessFloor==0, cache.complete=false; cache.status='Zero floor: safe UB1 for clipped service, no signed-service branch bound.'; end
result.subsetCounts=cache.subsetCounts; result.blockTrace=cache.blockTrace;
result.pricingComplete=cache.complete; result.pricingStatus=cache.status;
if cache.complete, result.minimumResourceCounts=cache.minimumCounts; end
if cache.complete
 pool=initial_pool(report,data,result.incumbentX,bestRecord);
 root=struct('fixed',-ones(K,M,'int8'),'pool',pool,'upper',upper,'id',1,'parent',0,'depth',0);
 open={root}; nextId=2; closedUpper=-Inf; status='node_limit';
 while ~isempty(open)
  upper=max([closedUpper,cellfun(@(n)n.upper,open),finite_lower(result.lowerBits)/1e6]);
  if met_gap(upper*1e6,result.lowerBits,options), status='gap_target_met'; break; end
  if toc(started)>=options.maxSeconds, status='time_limit'; break; end
  if result.nodesProcessed>=options.maxNodes, status='node_limit'; break; end
  [~,chosen]=max(cellfun(@(n)n.upper,open)); task=open{chosen}; open(chosen)=[];
  otherUpper=max([closedUpper,cellfun(@(n)n.upper,open),finite_lower(result.lowerBits)/1e6]);
  if task.upper*1e6<=finite_lower(result.lowerBits)+1e-3
   closedUpper=max(closedUpper,task.upper); continue;
  end
  node=leo_refine_certificate_node(data,cache,task.fixed,task.pool,task.upper,options,budget);
  result.nodesProcessed=result.nodesProcessed+1;
  if task.id==1
   result.rootRelaxationUpperBits=node.upper*1e6;
   result.rootLPConverged=strcmp(node.status,'full_lp_priced'); result.lambda=node.lambda;
  end
  % 整数舍入与修复均属于证书阶段的额外计算，不返回去帮助被测算法。
  candidates=node.roundedCandidates;
  if ~isempty(result.incumbentX), candidates=[{result.incumbentX},candidates]; end
  if ~isempty(node.roundedX), candidates=[{node.roundedX},candidates]; end
  bestCandidate=[]; bestCandidateService=[];
  for candidateIndex=1:numel(candidates)
   try
    candidate=candidates{candidateIndex};
    if toc(started)<options.maxSeconds
     localBudget=budget; localBudget.seconds=min(budget.seconds,toc(started)+options.recoverySeconds);
     coordinated=leo_round_column_schedule(data,node.pool,candidate,localBudget,12);
     candidate=coordinated.x;
    end
    s=leo_evaluate_service(data,candidate);
    if isempty(bestCandidateService) || better_at_floor(s,bestCandidateService,options.fairnessFloor)
     bestCandidate=candidate; bestCandidateService=s;
    end
   catch
   end
  end
  if ~isempty(bestCandidate) && toc(started)<options.maxSeconds
   problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
   repairOptions=leo_method_options(struct('verbose',false,'recoveryEvaluations',200,'recoveryPasses',4));
   localBudget=budget; seconds=options.recoverySeconds;
   if task.id==1, seconds=4*seconds; end
   localBudget.seconds=min(budget.seconds,toc(started)+seconds);
   if all(bestCandidateService.demandRatio>=options.fairnessFloor), phase='throughput'; floorValue=options.fairnessFloor;
   else, phase='fairness'; floorValue=0; end
   repaired=leo_recover_schedule(problem,bestCandidate,phase,floorValue,repairOptions,task.id,localBudget);
   if better_at_floor(repaired.service,bestCandidateService,options.fairnessFloor)
    bestCandidate=repaired.x; bestCandidateService=repaired.service;
   end
  end
  if ~isempty(bestCandidateService) && all(bestCandidateService.demandRatio>=options.fairnessFloor) && ...
          (isnan(result.lowerBits) || bestCandidateService.totalBits>result.lowerBits)
   if bestCandidateService.totalBits>upper*1e6+1e-6*max(1,abs(upper*1e6))
    error('leo:upperBoundInvalid','Recovered integer schedule exceeds prior global bound.');
   end
   result.lowerBits=bestCandidateService.totalBits; result.incumbentX=bestCandidate;
   result.bestMethod='certificate_search'; result.bestSeed=NaN;
  end
  for j=1:numel(node.trace)
   r=node.trace(j); result.pricingIterations=result.pricingIterations+1;
   r.node=task.id; r.nodeUpperBits=r.bestUpperBits;
   r.bestUpperBits=max([otherUpper*1e6,r.bestUpperBits,finite_lower(result.lowerBits)]);
   r.knownFeasibleLowerBits=result.lowerBits;
   if isempty(result.iterationTrace), result.iterationTrace=r; else, result.iterationTrace(end+1,1)=r; end
  end
  decision=0; closed=false;
  if node.hardInfeasible
   closed=true; node.upper=-Inf;
  elseif node.upper*1e6<sum(targets)-1e-3
   closed=true; % 任何全QoS日程的总服务至少为sum(q)。
  elseif node.upper*1e6<=finite_lower(result.lowerBits)+1e-3
   closed=true; closedUpper=max(closedUpper,node.upper);
  elseif toc(started)>=options.maxSeconds
   task.upper=node.upper; task.pool=node.pool; open{end+1}=task; status='time_limit';
  else
   free=task.fixed==-1;
   fraction=zeros(K,M);
   if ~isempty(node.fractionalX)
    fraction=min(node.fractionalX,1-node.fractionalX); fraction(~free)=-Inf;
   end
   [score,decision]=max(fraction(:));
   if ~any(free(:))
    x=task.fixed==1; s=leo_evaluate_service(data,x);
    if all(s.demandRatio>=options.fairnessFloor)
     if isnan(result.lowerBits) || s.totalBits>result.lowerBits
      result.lowerBits=s.totalBits; result.incumbentX=x; result.bestMethod='certificate_search'; result.bestSeed=NaN;
     end
     closedUpper=max(closedUpper,s.totalBits/1e6);
    end
    closed=true; decision=0;
   else
    if score<1e-7, decision=find(free,1,'first'); end
    % x_im=0 / x_im=1 是互斥、穷尽的原始二元分支；每个子节点仍完整定价。
    for value=0:1
     child=task; child.fixed(decision)=value; child.upper=node.upper;
     child.pool=node.pool; child.id=nextId; child.parent=task.id; child.depth=task.depth+1;
     nextId=nextId+1; open{end+1}=child;
    end
   end
  end
  upper=max([closedUpper,cellfun(@(n)n.upper,open),finite_lower(result.lowerBits)/1e6]);
  row=struct('node',task.id,'parent',task.parent,'depth',task.depth,'nodeUpperBits',node.upper*1e6, ...
   'globalUpperBits',upper*1e6,'integerLowerBits',result.lowerBits,'openNodes',numel(open), ...
   'branchVariable',decision,'closed',closed,'pricingStatus',node.status,'pricingRounds',node.rounds, ...
   'simplexPivots',node.simplexPivots,'masterValueBits',node.masterValue*1e6, ...
   'artificialDeficitBits',node.artificialServiceBits,'artificialCountDeficit',node.artificialCountDeficit);
  if isempty(result.branchTrace), result.branchTrace=row; else, result.branchTrace(end+1,1)=row; end
  if options.verbose
   fprintf('Certificate node %d: lower=%.6f upper=%.6f Mbit, open=%d, %s\n', ...
    task.id,result.lowerBits/1e6,upper,numel(open),node.status);
  end
 end
 if isempty(open)
  status='all_nodes_closed';
  if isnan(result.lowerBits), result.infeasibilityCertified=true; upper=0;
  else, upper=max(closedUpper,result.lowerBits/1e6); end
 end
 result.openNodeCount=numel(open);
 result.kind='Column generation and branch-and-price';
 if result.nodesProcessed==0, result.kind='UB1 or matching-data certificate already meets gap target'; end
 result.pricingStatus=status;
end
result.upperBits=max(0,upper*1e6)+1e-9*max(1,abs(upper*1e6));
if isfinite(result.lowerBits)
 if result.upperBits<result.lowerBits-1e-5*max(1,result.lowerBits)
  error('leo:upperBoundInvalid','Certificate upper bound is below an independently verified integer schedule.');
 end
 result.upperBits=max(result.upperBits,result.lowerBits);
 result.absoluteGapBits=max(0,result.upperBits-result.lowerBits);
 result.relativeGap=result.absoluteGapBits/max(result.upperBits,eps);
else
 result.absoluteGapBits=NaN; result.relativeGap=NaN;
end
result.gapTargetMet=met_gap(result.upperBits,result.lowerBits,options);
if ~isempty(result.incumbentX)
    check=leo_evaluate_service(data,result.incumbentX);
    assert(all(check.demandRatio>=options.fairnessFloor) && abs(check.totalBits-result.lowerBits)<1e-6*max(1,result.lowerBits));
    result.incumbentUserBits=check.userBits;
else
    result.incumbentUserBits=[];
end
result.elapsedSeconds=toc(started);
result.scope=sprintf('Fixed certified-service model at explicit min G/q >= %.17g; CONDITIONAL throughput optimum, not the stage-1 max-min optimum or stochastic capacity.',options.fairnessFloor);
end

function yes=better_at_floor(a,b,floorValue)
af=all(a.demandRatio>=floorValue); bf=all(b.demandRatio>=floorValue);
if af && bf, yes=a.totalBits>b.totalBits;
elseif af~=bf, yes=af;
else, yes=leo_service_is_better(a,b,'fairness',0); end
end

function pool=initial_pool(report,data,incumbent,bestRecord)
K=data.shape(1); M=data.shape(2); pool.groups=cell(1,M); pool.service=cell(1,M);
for m=1:M, pool.groups{m}=false(K,0); pool.service{m}=zeros(K,0); end
schedules={}; if ~isempty(incumbent), schedules{end+1}=incumbent; end
order=1:numel(report.records); if bestRecord>0, order=[bestRecord,order(order~=bestRecord)]; end
for j=order
 if strcmp(report.records(j).status,'completed') && ~isempty(report.solutions{j})
  schedules{end+1}=report.solutions{j}.x; %#ok<AGROW>
 end
end
schedules{end+1}=false(K,M);
for j=1:numel(schedules)
 for m=1:M
  group=logical(schedules{j}(:,m));
  if ~isempty(pool.groups{m}) && any(all(bsxfun(@eq,pool.groups{m},group),1)), continue; end
  pool.groups{m}(:,end+1)=group;
  pool.service{m}(:,end+1)=leo_resource_service(data,m,group)/1e6;
 end
end
end
function yes=met_gap(upper,lower,o)
yes=isfinite(lower) && upper-lower<=max(o.absoluteGapBits,o.relativeGap*max(upper,eps));
end
function value=finite_lower(value)
if ~isfinite(value), value=-Inf; end
end
function o=defaults(o)
values=struct('maxSeconds',180,'maxIterations',150,'maxBeams',18,'maxSubsets',200000, ...
 'maxTotalSubsets',1500000,'maxNodes',128,'maxSimplexPivots',10000, ...
 'cappedService',true,'countCuts',true,'roundingCandidates',8,'recoverySeconds',.25, ...
 'relativeGap',.0001,'absoluteGapBits',1,'pricingTolerance',1e-8,'artificialPenalty',1000,'verbose',true,'fairnessFloor',1);
names=fieldnames(o); assert(all(ismember(names,fieldnames(values))),'Unknown theory option.');
for j=1:numel(names), values.(names{j})=o.(names{j}); end
o=values;
for f={'maxIterations','maxBeams','maxSubsets','maxTotalSubsets','maxNodes','maxSimplexPivots','roundingCandidates'}
 v=o.(f{1}); assert(isscalar(v) && isfinite(v) && v>=1 && v==fix(v));
end
for f={'maxSeconds','relativeGap','absoluteGapBits','recoverySeconds','fairnessFloor'}
 v=o.(f{1}); assert(isscalar(v) && isfinite(v) && v>=0);
end
assert(isscalar(o.countCuts) && (o.countCuts==0 || o.countCuts==1));
assert(isscalar(o.cappedService) && (o.cappedService==0 || o.cappedService==1));
assert(o.pricingTolerance>0 && o.artificialPenalty>0);
end
