function result = leo_proxy_tabu_group(q,old,options,budget)
%LEO_PROXY_TABU_GROUP 在同一固定二次收益上做可行add/drop/swap禁忌搜索。
% 不计算原始SINR；原式验收、价格更新、切点刷新由公共外层负责。
% 允许当前状态退步；返回所有起点/迭代中最佳合法组，至少保留旧组。
rounds=80; restarts=4; tenure=7;
if isfield(options,'proxyTabuIterations'), rounds=options.proxyTabuIterations; end
if isfield(options,'proxyTabuRestarts'), restarts=options.proxyTabuRestarts; end
if isfield(options,'proxyTabuTenure'), tenure=options.proxyTabuTenure; end
score=@(x) q.A.'*double(x)-double(x).'*q.B*double(x)/2;
best=logical(old(:)); bestScore=score(best); completed=0; candidates=0; repaired=0;
for restart=1:restarts
    if leo_budget_expired(budget), break; end
    if restart==1, x=best; elseif restart==2, x=false(q.nUsers,1);
    else
        raw=rand(q.nUsers,1)<.5; x=leo_repair_group(q,raw); repaired=repaired+any(raw~=x);
    end
    value=score(x); tabuUntil=zeros(q.nUsers,1);
    if value>bestScore, best=x; bestScore=value; end
    for iteration=1:rounds
        if leo_budget_expired(budget), break; end
        selected=find(x); absent=find(~x); marginal=q.A-q.B*double(x);
        conflicts=bsxfun(@eq,q.beamIndex(absent),q.beamIndex(selected).');
        count=sum(conflicts,2); additions=marginal(absent);
        additions(count>0 | numel(selected)>=q.maxStreams)=-Inf;
        swaps=bsxfun(@minus,marginal(absent),marginal(selected).')+q.B(absent,selected);
        allowed=bsxfun(@or,count==0,bsxfun(@and,count==1,conflicts)); swaps(~allowed)=-Inf;
        choices=[additions,swaps].'; delta=[-marginal(selected);choices(:)];
        drops=[selected;repmat([0;selected],numel(absent),1)];
        adds=[zeros(numel(selected),1);kron(absent,ones(numel(selected)+1,1))];
        candidates=candidates+nnz(isfinite(delta)); completed=completed+1;
        blocked=[false;tabuUntil>iteration];
        forbidden=(blocked(drops+1) | blocked(adds+1)) & value+delta<=bestScore;
        delta(forbidden)=-Inf; [gain,at]=max(delta);
        if isempty(gain) || ~isfinite(gain), continue; end
        if drops(at)>0, x(drops(at))=false; tabuUntil(drops(at))=iteration+tenure; end
        if adds(at)>0, x(adds(at))=true; tabuUntil(adds(at))=iteration+tenure; end
        value=score(x);
        if value>bestScore, best=x; bestScore=value; end
    end
end
result=struct('x',best,'score',bestScore,'iterations',completed,'candidates',candidates,'repaired',repaired);
end
