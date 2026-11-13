function c=leo_v16_initial_bounds(report,phase,s0)
% Fast valid seed interval. Full original certification is RUN_V17_BOUNDS.
if nargin<3, s0=0; end
d=report.problemData; K=d.shape(1); M=d.shape(2); lower=-Inf; bestX=[]; best=[];
for j=1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed'), continue; end
    solution=report.solutions{j}; xs={solution.x};
    if isfield(solution,'stage1'), xs{end+1}=solution.stage1.x; end
    for k=1:numel(xs)
        s=leo_evaluate_service(d,xs{k}); value=s.fairness;
        if strcmp(phase,'throughput')
            value=-Inf; if all(s.demandRatio>=s0), value=s.totalBits/1e6; end
        end
        if value>lower, lower=value; best=s; bestX=xs{k}; end
    end
end
if strcmp(phase,'fairness')
    if isempty(bestX), bestX=false(K,M); best=leo_evaluate_service(d,bestX); lower=best.fairness; end
    b=leo_cardinality_fairness_bound(report,struct('maxSeconds',Inf,'maxIterations',150)); upper=b.upper;
else
    b=leo_v14_floor_bound(report,s0,150); upper=b.upperBits/1e6;
end
c=struct('lower',lower,'upper',upper,'incumbentX',bestX,'incumbentService',best, ...
    'absoluteGap',max(0,upper-lower),'relativeGap',max(0,upper-lower)/max(upper,eps), ...
    'gapTargetMet',false,'status','initial_relaxation_only','nodesProcessed',0,'openNodeCount',1, ...
    'pricingComplete',false,'branchTrace',struct([]),'elapsedSeconds',NaN,'problemDataSnapshot',d, ...
    'options',struct('absoluteGap',1e-6,'relativeGap',.001),'boundSchemaVersion',3, ...
    'scope','Initial ORIGINAL relaxation interval. Independent branch-and-price can tighten it with RUN_V17_BOUNDS.');
if strcmp(phase,'fairness')
    c.cardinalityRelaxation=b; c.coarseUpper=leo_fairness_limit(d);
else
    c.fairnessFloor=s0; c.lowerBits=lower*1e6; c.upperBits=upper*1e6;
    c.pricingStatus=c.status; c.absoluteGapBits=c.absoluteGap*1e6;
    c.targetAbsoluteGapBits=1; c.targetRelativeGap=.001; c.kind='Original floor-dependent initial dual bound';
end
end
