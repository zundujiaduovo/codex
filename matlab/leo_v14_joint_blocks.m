function r=leo_v14_joint_blocks(problem,start,banks,phase,s0,o,budget)
% 从最弱用户相关块中挑2--3块；笛卡尔组合允许跨块补偿后共同验收。
d=problem.data; M=d.shape(2); c=o.coordination; r=start;
r.evaluations=0; r.accepted=0; r.blocks=[]; r.sources={}; r.resourceEvaluations=0;
if M<2, return; end
[~,weak]=min(start.service.demandRatio); priority=-Inf(1,M); pools=cell(1,M); bits=cell(1,M); labels=cell(1,M);
for m=1:M
    groups=start.x(:,m); sources={'incumbent'};
    if ~isempty(banks{m}), groups=[groups,banks{m}.groups]; sources=[sources,banks{m}.sources]; end
    [~,at]=unique(groups.','rows','stable'); groups=groups(:,at); sources=sources(at);
    b=leo_resource_group_services(d,m,groups); gain=bsxfun(@rdivide,bsxfun(@minus,b,start.service.resourceBits(:,m)),d.qosTargetBits);
    r.resourceEvaluations=r.resourceEvaluations+size(groups,2);
    usefulness=gain(weak,:)+.2*sum(max(0,gain),1); [~,rank]=sort(usefulness,'descend');
    pick=unique([1,rank(1:min(c.jointPool-1,numel(rank)))],'stable');
    pools{m}=groups(:,pick); bits{m}=b(:,pick); labels{m}=sources(pick); priority(m)=max(usefulness);
end
[~,order]=sort(priority,'descend'); selected=order(1:min(c.jointBlocks,M));
best=start.service; chosen=zeros(1,numel(selected)); sizes=cellfun(@(x)size(x,2),pools(selected));
for index=0:min(prod(sizes),c.jointMaxCombinations)-1
    if leo_budget_expired(budget), break; end
    n=index; ids=ones(1,numel(selected)); trialBits=start.service.resourceBits;
    for j=1:numel(selected)
        ids(j)=mod(n,sizes(j))+1; n=floor(n/sizes(j)); trialBits(:,selected(j))=bits{selected(j)}(:,ids(j));
    end
    if all(ids==1), continue; end
    service=leo_service_totals(d,trialBits); r.evaluations=r.evaluations+1;
    if leo_service_is_better(service,best,phase,s0), best=service; chosen=ids; end
end
if any(chosen)
    x=start.x;
    for j=1:numel(selected), x(:,selected(j))=pools{selected(j)}(:,chosen(j)); end
    exact=problem.evaluate(x);
    if leo_service_is_better(exact,start.service,phase,s0)
        r.x=x; r.service=exact; r.accepted=1; r.blocks=selected;
        for j=1:numel(selected), r.sources{j}=labels{selected(j)}{chosen(j)}; end
    end
end
end
