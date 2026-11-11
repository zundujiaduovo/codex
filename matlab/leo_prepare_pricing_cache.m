function cache = leo_prepare_pricing_cache(data,options,budget)
%LEO_PREPARE_PRICING_CACHE 为分支定价枚举全部合法波束子集；未完成不能作完整界。
K=data.shape(1); M=data.shape(2); [scale,~]=leo_service_adjustment(data);
cache.blocks=cell(1,M); cache.complete=false; cache.status='';
cache.subsetCounts=zeros(1,M); cache.blockTrace=struct([]);
for m=1:M
    if toc(budget.timer)>=budget.seconds, cache.status='time limit during enumeration'; return; end
    ids=find(data.available(:,m)); beams=unique(data.beamIndex(ids,m)); B=numel(beams);
    if B>options.maxBeams, cache.status='beam count exceeds exact pricing limit'; return; end
    count=0; for n=0:min(B,data.maxStreams), count=count+nchoosek(B,n); end
    if count>options.maxSubsets || sum(cache.subsetCounts)+count>options.maxTotalSubsets
        cache.status='subset count exceeds exact pricing limit'; return;
    end
    masks=uint32((0:2^B-1).'); chosen=false(numel(masks),B);
    for b=1:B, chosen(:,b)=logical(bitget(masks,b)); end
    chosen=chosen(sum(chosen,2)<=data.maxStreams,:); count=size(chosen,1);
    local=zeros(K,1);
    for b=1:B, local(ids(data.beamIndex(ids,m)==beams(b)))=b; end
    rates=zeros(K,count);
    for t=find(data.slotToResource==m & data.dataDurationS>0)
        C=data.design.beamPowerW(:,beams,t);
        for i=ids.', C(i,local(i))=0; end
        denom=bsxfun(@plus,data.design.noiseW(:,t),C*double(chosen.'));
        sinr=bsxfun(@rdivide,data.design.signalW(:,t),denom);
        rates=rates+data.dataDurationS(t)*data.bandwidthHz/log(2)*log1p(sinr)/1e6;
    end
    rates=bsxfun(@times,scale,rates); rates(~data.available(:,m),:)=0;
    for i=ids.', rates(i,:)=rates(i,:).*double(chosen(:,local(i)).'); end
    cache.blocks{m}=struct('beams',beams,'chosen',chosen,'rates',rates,'local',local,'ids',ids);
    cache.subsetCounts(m)=count;
    row=struct('resource',m,'availableUsers',numel(ids),'availableBeams',B,'subsets',count);
    if isempty(cache.blockTrace), cache.blockTrace=row; else, cache.blockTrace(end+1,1)=row; end
    if options.verbose, fprintf('Theory pricing cache: block %d/%d, %d beams, %d subsets\n',m,M,B,count); end
end
[~,margin]=leo_service_adjustment(data); target=(leo_certificate_targets(data)+margin)/1e6;
maximum=zeros(K,M);
for m=1:M, maximum(:,m)=max(cache.blocks{m}.rates,[],2)*(1+1e-10)+1e-12; end
sorted=sort(maximum,2,'descend'); cumulative=cumsum(sorted,2);
cache.minimumCounts=repmat(M+1,K,1);
for i=1:K
    n=find(cumulative(i,:)>=target(i),1,'first');
    if ~isempty(n), cache.minimumCounts(i)=n; end
end
cache.userResourceUpperBits=maximum*1e6;
cache.complete=true; cache.status='all legal beam subsets cached';
end
