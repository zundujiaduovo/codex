function r = leo_accept_resource_candidates(problem,x,service,m,inner,phase,s0,budget)
%LEO_ACCEPT_RESOURCE_CANDIDATES 对候选池按原周期服务和完整 QoS 门槛排序。
% 单块只重算受影响的服务；选中后用完整原式复核。代理第一名另供价格链。
if nargin<8, budget=[]; end
r.x=x; r.service=service; r.evaluations=0; r.accepted=false;
r.nonProxyWinner=false; r.source='none';
r.candidateClass='none';
if isfield(inner,'candidateGroups')
    groups=inner.candidateGroups; sources=inner.candidateSources;
else
    groups=inner.x; sources={'solver'};
end
winner=0;
for j=1:size(groups,2)
    if leo_budget_expired(budget), break; end
    if isequal(groups(:,j),x(:,m)), continue; end
    bits=service.resourceBits; bits(:,m)=leo_resource_service(problem.data,m,groups(:,j));
    candidate=leo_service_totals(problem.data,bits); r.evaluations=r.evaluations+1;
    if leo_service_is_better(candidate,r.service,phase,s0)
        winner=j; r.service=candidate;
    end
end
if winner>0
    trial=x; trial(:,m)=groups(:,winner); exact=problem.evaluate(trial);
    if leo_service_is_better(exact,service,phase,s0)
        r.x=trial; r.service=exact; r.accepted=true; r.source=sources{winner};
        r.candidateClass=r.source;
        if isfield(inner,'candidateClasses'), r.candidateClass=inner.candidateClasses{winner}; end
        r.nonProxyWinner=~isequal(groups(:,winner),inner.x);
    else
        r.service=service;
    end
end
end
