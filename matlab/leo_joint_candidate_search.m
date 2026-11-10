function r = leo_joint_candidate_search(problem,start,banks,phase,s0,options,attempt,budget)
%LEO_JOINT_CANDIDATE_SEARCH 两块候选笛卡尔组合，允许跨块补偿后共同验收。
% SB/Local 都使用相同协调器；不调用上界、精确枚举或另一种求解器。
data=problem.data; M=data.shape(2); r=start; r.evaluations=0; r.accepted=0;
if M<2, return; end
for pair=1:options.jointPairsPerTrigger
    if leo_budget_expired(budget), break; end
    index=(attempt-1)*options.jointPairsPerTrigger+pair-1;
    m=mod(index,M)+1; distance=mod(floor(index/M),M-1)+1; n=mod(m-1+distance,M)+1;
    left=pool(m); right=pool(n); valuesLeft=zeros(data.shape(1),size(left,2));
    valuesRight=zeros(data.shape(1),size(right,2));
    for j=1:size(left,2), valuesLeft(:,j)=leo_resource_service(data,m,left(:,j)); end
    for j=1:size(right,2), valuesRight(:,j)=leo_resource_service(data,n,right(:,j)); end
    winner=[0,0]; best=r.service; checked=0;
    for a=1:size(left,2)
        for b=1:size(right,2)
            if leo_budget_expired(budget) || checked>=options.jointMaxCombinations, break; end
            if isequal(left(:,a),r.x(:,m)) && isequal(right(:,b),r.x(:,n)), continue; end
            bits=r.service.resourceBits; bits(:,m)=valuesLeft(:,a); bits(:,n)=valuesRight(:,b);
            trial=leo_service_totals(data,bits); r.evaluations=r.evaluations+1; checked=checked+1;
            if leo_service_is_better(trial,best,phase,s0), best=trial; winner=[a,b]; end
        end
        if leo_budget_expired(budget) || checked>=options.jointMaxCombinations, break; end
    end
    if winner(1)>0
        candidate=r.x; candidate(:,m)=left(:,winner(1)); candidate(:,n)=right(:,winner(2));
        exact=problem.evaluate(candidate);
        if leo_service_is_better(exact,r.service,phase,s0)
            r.x=candidate; r.service=exact; r.accepted=r.accepted+1;
        end
    end
end
    function groups=pool(block)
        groups=r.x(:,block);
        if ~isempty(banks{block})
            groups=[groups,banks{block}]; groups=unique(groups.','rows','stable').';
        end
    end
end
