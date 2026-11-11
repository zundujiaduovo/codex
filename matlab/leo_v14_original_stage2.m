function stage=leo_v14_original_stage2(problem,start,kind,s0,o,budget)
% 原目标Tabu/Greedy的独立同门槛阶段，不执行任何第一阶段搜索。
best=start; current=start; tabu=zeros(problem.data.shape); evaluations=0;
history=leo_record_search_step([],best.service,0,0,0); count=0;
if strcmp(kind,'greedy')
    candidate=leo_original_greedy(problem,start,'throughput',s0,budget);
    if leo_service_is_better(candidate.service,best.service,'throughput',s0), best=candidate; end
    history=candidate.history; count=candidate.iterations; evaluations=candidate.evaluations;
else
 for k=1:o.originalThroughputRounds
    pool=leo_original_neighbors(problem,current.x,current.service,o.recoveryEvaluations,k,budget);
    evaluations=evaluations+numel(pool); at=0;
    for j=1:numel(pool)
        if any(pool(j).service.demandRatio<s0), continue; end
        aspiration=leo_service_is_better(pool(j).service,best.service,'throughput',s0);
        if any(tabu(pool(j).changed)>k) && ~aspiration, continue; end
        if at==0 || leo_service_is_better(pool(j).service,pool(at).service,'throughput',s0), at=j; end
    end
    if at>0, current=pool(at); tabu(current.changed)=k+5; end
    if leo_service_is_better(current.service,best.service,'throughput',s0), best=current; end
    count=k; history=leo_record_search_step(history,best.service,k,toc(budget.timer),evaluations);
 end
end
assert(all(best.service.demandRatio>=s0));
stage=struct('x',best.x,'service',best.service,'history',history,'iterations',count, ...
    'fairnessFloor',s0,'evaluations',evaluations,'elapsedSeconds',toc(budget.timer));
end
