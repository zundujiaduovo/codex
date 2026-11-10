function a = leo_resource_candidate_archive(q,old,raw,origin,options,budget)
%LEO_RESOURCE_CANDIDATE_ARCHIVE 保留修复前后/润色后的不同合法候选及来源。
% 价格链仍返回代理最好组；原目标筛选另外使用有限且含旧组的候选池。
if nargin<6, budget=[]; end
old=logical(old(:)); raw=logical(raw);
[~,distinct]=unique(raw.','rows','stable'); raw=raw(:,distinct); origin=origin(distinct);
groups=old; sources={'warm_start'}; scores=score(old); repairs=0; legal=0; better=0;
for j=1:size(raw,2)
    if j>1 && leo_budget_expired(budget), break; end
    z=raw(:,j); ids=find(z);
    legal=legal+double(numel(ids)<=q.maxStreams && numel(unique(q.beamIndex(ids)))==numel(ids));
    fixed=leo_repair_group(q,z); repairs=repairs+any(z~=fixed);
    value=score(fixed);
    if any(strcmp(origin{j},{'sb','local'})) && value>score(old)+1e-12*max(1,abs(score(old))), better=better+1; end
    append(fixed,origin{j});
    if ~leo_budget_expired(budget)
        polished=leo_polish_group(q,fixed,options.polishMoves);
        append(polished,[origin{j},'_polish']);
    end
end
[bestScore,best]=max(scores); chosen=1;
if best~=1, chosen(end+1)=best; end
[~,rank]=sort(scores,'descend'); quota=min(options.candidatePoolSize,ceil(options.candidatePoolSize/2));
for j=rank(:).'
    if numel(chosen)>=quota, break; end
    if ~any(chosen==j), chosen(end+1)=j; end %#ok<AGROW>
end
% 剩余额度优先保留与已选候选不同的组，避免所有轨迹润色到同一组。
while numel(chosen)<min(options.candidatePoolSize,size(groups,2))
    available=setdiff(1:size(groups,2),chosen,'stable'); distance=zeros(size(available));
    for j=1:numel(available)
        distance(j)=min(sum(bsxfun(@ne,groups(:,available(j)),groups(:,chosen)),1));
    end
    candidates=available(distance==max(distance)); [~,at]=max(scores(candidates));
    chosen(end+1)=candidates(at); %#ok<AGROW>
end
a.best=groups(:,best); a.bestScore=bestScore; a.bestSource=sources{best};
a.groups=groups(:,chosen); a.scores=scores(chosen); a.sources=sources(chosen);
a.oldScore=score(old); a.nRepaired=repairs; a.rawCandidates=size(raw,2);
a.legalRawCandidates=legal; a.uniqueCandidates=size(groups,2); a.solverBetterCandidates=better;
    function value=score(z)
        z=double(z); value=q.A.'*z-z.'*q.B*z/2;
    end
    function append(z,source)
        if any(all(bsxfun(@eq,groups,z),1)), return; end
        groups(:,end+1)=z; sources{end+1}=source; scores(end+1)=score(z);
    end
end
