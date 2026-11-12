function [r,state]=leo_v15_price_block(d,m,w,fixed,o,state,seeds)
% Certified ORIGINAL weighted-service pricing, without pre-enumerating 2^B groups.
% For each possible final cardinality, undecided interference is bounded below
% by the required number of smallest remaining beam powers for EACH receiver.
% This optimistic bound is used only for pruning; every incumbent uses true SINR.
% A stopped tree returns max(incumbent, every open-node upper), never the best
% found group as an upper. Branches include/exclude one common physical beam.
if nargin<6, state=[]; end
if nargin<7, seeds=false(d.shape(1),0); end
K=d.shape(1); w=w(:); fixed=int8(fixed(:));
assert(numel(w)==K && all(isfinite(w) & w>=0) && numel(fixed)==K && all(ismember(fixed,[-1,0,1])));
ids=find(d.available(:,m)); beams=unique(d.beamIndex(ids,m)); B=numel(beams);
allowed=cell(1,B); must=false(1,B); possible=false(1,B); local=zeros(K,1);
hard=any(fixed==1 & ~d.available(:,m));
for b=1:B
    users=ids(d.beamIndex(ids,m)==beams(b)); local(users)=b;
    forced=users(fixed(users)==1); allowed{b}=users(fixed(users)~=0);
    if numel(forced)>1, hard=true; end
    if ~isempty(forced), allowed{b}=forced; must(b)=true; end
    possible(b)=~isempty(allowed{b});
end
hard=hard || nnz(must)>d.maxStreams;
if hard
    r=struct('upper',-Inf,'lower',-Inf,'group',false(K,1),'serviceBits',zeros(K,1), ...
        'complete',true,'hardInfeasible',true,'expanded',0,'openNodes',0,'status','hard_infeasible');
    state=[]; return;
end
slots=find(d.slotToResource==m & d.dataDurationS>0); H=numel(slots);
[scale,~]=leo_service_adjustment(d); S=d.design.signalW(:,slots); N=d.design.noiseW(:,slots);
assert(all(isfinite(S(:)) & S(:)>=0) && all(isfinite(N(:)) & N(:)>0) && all(isfinite(scale) & scale>=0));
C=zeros(K,B,H);
for t=1:H
    C(:,:,t)=d.design.beamPowerW(:,beams,slots(t));
    for i=ids.', C(i,local(i),t)=0; end
end
assert(all(isfinite(C(:)) & C(:)>=0),'The pricing bound requires finite nonnegative physical interference.');
factors=bsxfun(@times,scale(:),reshape(d.dataDurationS(slots),1,[])*d.bandwidthHz/log(2)/1e6);
signature=struct('resource',m,'weights',w,'fixed',fixed,'guard',o.arithmeticGuard,'tolerance',o.pricingTolerance);
if isempty(state)
    state=struct('signature',signature,'open',{{}},'bestScore',-Inf,'bestGroup',false(K,1), ...
        'bestBits',zeros(K,1),'retiredUpper',-Inf,'expanded',0);
    [value,group,bits]=exact(must); update(value,group,bits);
    for j=1:size(seeds,2)
        group=logical(seeds(:,j));
        if numel(group)~=K || any(group & ~d.available(:,m)) || nnz(group)>d.maxStreams || ...
                numel(unique(d.beamIndex(group,m)))~=nnz(group) || any(group(fixed==0)) || any(~group(fixed==1)), continue; end
        bits=leo_resource_service(d,m,group); update(w.'*bits/1e6,group,bits);
    end
    root=struct('on',must,'free',possible & ~must,'upper',Inf,'choice',0);
    root=bound(root); state.open={root};
else
    assert(isequaln(state.signature,signature),'Pricing checkpoint belongs to different weights/branch restrictions.');
end
expanded=0;
while ~isempty(state.open) && expanded<o.pricingNodesPerCall
    [~,at]=max(cellfun(@(x)x.upper,state.open)); node=state.open{at}; state.open(at)=[];
    if node.upper<=state.bestScore+o.pricingTolerance
        state.retiredUpper=max(state.retiredUpper,node.upper); continue;
    end
    expanded=expanded+1; state.expanded=state.expanded+1;
    [value,group,bits]=exact(node.on); update(value,group,bits);
    if node.choice==0
        state.retiredUpper=max(state.retiredUpper,node.upper); continue;
    end
    % One common beam is switched for all receivers, preserving interference coupling.
    b=node.choice;
    for take=[true,false]
        child=node; child.free(b)=false; child.on(b)=take;
        if nnz(child.on)>d.maxStreams, continue; end
        child=bound(child); child.upper=min(node.upper,child.upper);
        if child.upper>state.bestScore+o.pricingTolerance, state.open{end+1}=child;
        else, state.retiredUpper=max(state.retiredUpper,child.upper); end
    end
end
upper=max([state.bestScore,state.retiredUpper,cellfun(@(x)x.upper,state.open)]);
r=struct('upper',upper,'lower',state.bestScore,'group',state.bestGroup,'serviceBits',state.bestBits, ...
    'complete',isempty(state.open),'hardInfeasible',false,'expanded',expanded, ...
    'openNodes',numel(state.open),'status','pricing_node_limit');
if r.complete, r.status='pricing_tree_closed'; end

    function update(value,group,bits)
        if value>state.bestScore
            state.bestScore=value; state.bestGroup=group; state.bestBits=bits;
        end
    end
    function [value,group,bits]=exact(on)
        % For a fixed active beam subset, receiver choice within each beam is
        % independent: its interference depends on beams, not on their users.
        I=zeros(K,H);
        for h=1:H, I(:,h)=sum(C(:,on,h),2); end
        rates=sum(factors.*log1p(S./(N+I)),2); group=false(K,1);
        for bb=find(on)
            users=allowed{bb}; [~,j]=max(w(users).*rates(users)); group(users(j))=true;
        end
        bits=1e6*rates.*group; value=w.'*bits/1e6;
    end
    function node=bound(node)
        selected=find(node.on); remaining=find(node.free); a=numel(selected); R=numel(remaining);
        maxAdd=min(R,d.maxStreams-a); I=zeros(K,H);
        for h=1:H, I(:,h)=sum(C(:,selected,h),2); end
        % For remaining-beam users exclude their own beam from optional interferers.
        prefix=zeros(K,R+1,H);
        for h=1:H
            optional=C(:,remaining,h);
            for z=1:R, optional(local==remaining(z),z)=Inf; end
            prefix(:,2:end,h)=cumsum(sort(optional,2),2);
        end
        best=-Inf; choice=0;
        for add=0:maxAdd
            rates=zeros(K,1);
            for h=1:H
                if add==0, extra=zeros(K,1);
                else
                    extra=prefix(:,add+1,h);
                    future=ismember(local,remaining); extra(future)=prefix(future,add,h);
                end
                rates=rates+factors(:,h).*log1p(S(:,h)./(N(:,h)+I(:,h)+extra));
            end
            beamValues=zeros(1,B);
            for bb=[selected,remaining]
                users=allowed{bb}; beamValues(bb)=max(w(users).*rates(users));
            end
            [sorted,order]=sort(beamValues(remaining),'descend');
            candidate=sum(beamValues(selected))+sum(sorted(1:add));
            if candidate>best
                best=candidate; choice=0;
                if add>0, choice=remaining(order(1)); end
            end
        end
        % Even if the best cardinality is a, excluding an undecided beam can
        % expose other cardinalities. All completions must remain represented.
        if R>0 && a<d.maxStreams && choice==0, choice=remaining(1); end
        if R==0 || a==d.maxStreams, choice=0; end
        node.upper=best+o.arithmeticGuard*max(1,abs(best)); node.choice=choice;
    end
end
