function priced = leo_price_node(data,cache,lambda,fixed,budget,capped,objectiveWeights)
%LEO_PRICE_NODE 在原用户-块二元变量分支条件下，对每块全部合法组精确定价。
K=data.shape(1); M=data.shape(2);
if nargin<7, objectiveWeights=ones(K,1); end
assert(isequal(size(objectiveWeights),[K,1]) && all(isfinite(objectiveWeights) & objectiveWeights>=0));
[~,margin]=leo_service_adjustment(data); target=(leo_certificate_targets(data)+margin)/1e6;
countPrices=zeros(K,1);
if numel(lambda)>K, countPrices=lambda(K+1:end); end
lambda=lambda(1:K);
if any(~isfinite(lambda)) || any(~isfinite(countPrices)), priced.complete=false; priced.hardInfeasible=false; return; end
priced.complete=false; priced.hardInfeasible=false;
priced.total=0; priced.groups=false(K,M); priced.service=zeros(K,M);
priced.support=zeros(1,M);
for m=1:M
    if toc(budget.timer)>=budget.seconds, return; end
    block=cache.blocks{m}; must=find(fixed(:,m)==1);
    if numel(must)>data.maxStreams || any(~data.available(must,m)) || ...
            numel(unique(data.beamIndex(must,m)))<numel(must)
        priced.complete=true; priced.hardInfeasible=true; return;
    end
    legal=true(size(block.chosen,1),1); scores=zeros(1,size(block.rates,2));
    for b=1:numel(block.beams)
        ids=block.ids(data.beamIndex(block.ids,m)==block.beams(b) & fixed(block.ids,m)~=0);
        forced=ids(fixed(ids,m)==1);
        if ~isempty(forced)
            ids=forced; legal=legal & block.chosen(:,b);
        elseif isempty(ids)
            legal=legal & ~block.chosen(:,b);
        end
        if ~isempty(ids)
            values=block.rates(ids,:); coverage=values;
            if capped, coverage=bsxfun(@min,coverage,target(ids)); end
            scores=scores+max(bsxfun(@times,objectiveWeights(ids),values)+bsxfun(@times,lambda(ids),coverage)+ ...
                bsxfun(@times,countPrices(ids),double(block.chosen(:,b).')),[],1);
        end
    end
    scores(~legal.')=-Inf; [value,choice]=max(scores);
    if ~any(legal), priced.complete=true; priced.hardInfeasible=true; return; end
    if ~isfinite(value), return; end
    group=false(K,1);
    for b=find(block.chosen(choice,:))
        ids=block.ids(data.beamIndex(block.ids,m)==block.beams(b) & fixed(block.ids,m)~=0);
        forced=ids(fixed(ids,m)==1); if ~isempty(forced), ids=forced; end
        values=block.rates(ids,choice); coverage=values;
        if capped, coverage=min(coverage,target(ids)); end
        [~,j]=max(objectiveWeights(ids).*values+lambda(ids).*coverage+countPrices(ids)); group(ids(j))=true;
    end
    priced.groups(:,m)=group; priced.service(:,m)=block.rates(:,choice).*group;
    priced.support(m)=value; priced.total=priced.total+value;
end
priced.complete=true;
end
