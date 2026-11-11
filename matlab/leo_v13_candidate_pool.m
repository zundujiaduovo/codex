function pool=leo_v13_candidate_pool(q,groups,sources,limit)
% 合法候选保留代理高分及Hamming距离多样性，首列始终保留旧组。
[~,at]=unique(groups.','rows','stable'); groups=groups(:,at); sources=sources(at);
z=double(groups); scores=q.A.'*z-sum(z.*(q.B*z),1)/2;
[~,rank]=sort(scores,'descend'); selected=1;
if rank(1)~=1, selected(end+1)=rank(1); end
for j=rank
    if numel(selected)>=ceil(limit/2), break; end
    if ~any(selected==j), selected(end+1)=j; end %#ok<AGROW>
end
while numel(selected)<min(limit,size(groups,2))
    available=setdiff(1:size(groups,2),selected,'stable'); distance=zeros(size(available));
    for j=1:numel(available)
        distance(j)=min(sum(bsxfun(@ne,groups(:,available(j)),groups(:,selected)),1));
    end
    tied=available(distance==max(distance)); [~,j]=max(scores(tied)); selected(end+1)=tied(j); %#ok<AGROW>
end
pool=struct('groups',groups(:,selected),'sources',{sources(selected)});
end
