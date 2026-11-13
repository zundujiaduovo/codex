function stage=leo_v14_original_stage2(problem,start,kind,s0,o,budget)
% 原目标Tabu/Greedy的独立同门槛阶段，不执行任何第一阶段搜索。
best=start; current=start; tabu=zeros(problem.data.shape); evaluations=0;
history=leo_record_search_step([],best.service,0,0,0); count=0;
conv=leo_v16_convergence_options(); if isfield(o,'convergence'), conv=o.convergence; end
[convergence,~]=leo_v16_convergence_step(o,'throughput',best.service,0,[],'original');
if strcmp(kind,'greedy')
    candidate=leo_original_greedy(problem,start,'throughput',s0,budget);
    if leo_service_is_better(candidate.service,best.service,'throughput',s0), best=candidate; end
    history=candidate.history; count=candidate.iterations; evaluations=candidate.evaluations;
else
 k=0;
 while conv.enabled || k<o.originalThroughputRounds
    k=k+1;
    randomize=isfield(o,'searchPolicy') && o.searchPolicy.randomizeNeighbors && mod(k,5)==0;
    pool=leo_original_neighbors(problem,current.x,current.service,o.recoveryEvaluations,k,budget,randomize);
    evaluations=evaluations+numel(pool); at=0;
    for j=1:numel(pool)
        if any(pool(j).service.demandRatio<s0), continue; end
        aspiration=leo_service_is_better(pool(j).service,best.service,'throughput',s0);
        if any(tabu(pool(j).changed)>k) && ~aspiration, continue; end
        if at==0 || leo_service_is_better(pool(j).service,pool(at).service,'throughput',s0), at=j; end
    end
    if at>0
        candidate=pool(at); candidate.service=problem.evaluate(candidate.x);
        if all(candidate.service.demandRatio>=s0), current=candidate; tabu(current.changed)=k+5; end
    end
    if leo_service_is_better(current.service,best.service,'throughput',s0), best=current; end
    count=k; history=leo_record_search_step(history,best.service,k,toc(budget.timer),evaluations);
    [convergence,converged]=leo_v16_convergence_step(o,'throughput',best.service,k,convergence,'original');
    if converged, break; end
 end
end
assert(all(best.service.demandRatio>=s0));
stage=struct('x',best.x,'service',best.service,'history',history,'iterations',count, ...
    'fairnessFloor',s0,'evaluations',evaluations,'elapsedSeconds',toc(budget.timer),'convergence',convergence);
end
