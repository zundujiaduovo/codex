function r=leo_v15_master(d,pool,fixed,phase,floorValue,cap,o)
% Restricted configuration LP: its primal objective is NEVER a global upper.
% Original per-group services only. Artificial variables give an initial basis.
K=d.shape(1); M=d.shape(2); fair=strcmp(phase,'fairness');
[~,margin]=leo_service_adjustment(d); target=margin./d.qosTargetBits;
if ~fair, target=target+floorValue; end
rho=d.qosTargetBits/1e6; groups=cell(1,M); ratios=cell(1,M);
first=zeros(K,M); firstGroup=false(K,M); r.hardInfeasible=false;
for m=1:M
    forced=fixed(:,m)==1;
    if any(forced & ~d.available(:,m)) || nnz(forced)>d.maxStreams || numel(unique(d.beamIndex(forced,m)))~=nnz(forced)
        r.hardInfeasible=true; return;
    end
    keep=all(bsxfun(@or,fixed(:,m)==-1,bsxfun(@eq,pool.groups{m},fixed(:,m))),1);
    groups{m}=pool.groups{m}(:,keep); ratios{m}=pool.ratios{m}(:,keep);
    if isempty(groups{m})
        groups{m}=forced; ratios{m}=leo_resource_service(d,m,forced)./d.qosTargetBits;
    end
    first(:,m)=ratios{m}(:,1); firstGroup(:,m)=groups{m}(:,1);
end
if fair
    A=[eye(M),zeros(M,2*K+2);first,-ones(K,1),-eye(K),eye(K),zeros(K,1); ...
        zeros(1,M),1,zeros(1,2*K),1];
    b=[ones(M,1);target;cap]; c=[zeros(M,1);1;zeros(K,1);-1000*ones(K,1);0];
    surplus=M+1+(1:K); artificial=M+1+K+(1:K); basis=[1:M,surplus,M+2*K+2];
else
    A=[eye(M),zeros(M,2*K);first,-eye(K),eye(K)]; b=[ones(M,1);target];
    c=[(rho.'*first).';zeros(K,1);-1000*max(1,sum(rho))*ones(K,1)];
    surplus=M+(1:K); artificial=M+K+(1:K); basis=[1:M,surplus];
end
missing=find(sum(first,2)<target); basis(M+missing)=artificial(missing);
owner=[1:M,zeros(1,size(A,2)-M)]; masks=[firstGroup,false(K,size(A,2)-M)];
for m=1:M
    for j=2:size(groups{m},2)
        a=[zeros(M,1);ratios{m}(:,j)]; a(m)=1; if fair, a(end+1)=0; end
        A(:,end+1)=a; c(end+1,1)=0; if ~fair, c(end)=rho.'*ratios{m}(:,j); end
        owner(end+1)=m; masks(:,end+1)=groups{m}(:,j);
    end
end
budget=struct('timer',tic,'seconds',Inf);
lp=leo_simplex_feasible(A,b,c,basis,budget,o.maxSimplexPivots);
assert(all(isfinite(lp.dual)),'V15 restricted master failed to produce finite prices.');
r.lambda=max(0,-lp.dual(M+(1:K))); r.cap=cap;
r.weights=r.lambda.*(1e6./d.qosTargetBits);
r.constant=-r.lambda.'*target;
if fair, r.constant=r.constant+cap*max(0,1-sum(r.lambda));
else, r.weights=r.weights+1; r.constant=r.constant-sum(margin)/1e6; end
r.masterValue=lp.objective; if ~fair, r.masterValue=r.masterValue-sum(margin)/1e6; end
r.masterStatus=lp.status; r.artificial=sum(lp.x(artificial));
r.fractionalX=zeros(K,M); r.rounded=cell(1,o.roundingCandidates);
for j=1:o.roundingCandidates, r.rounded{j}=false(K,M); end
for m=1:M
    ids=find(owner==m); v=lp.x(ids); total=sum(v);
    if total<=0, v=zeros(size(v)); v(1)=1; total=1; end
    r.fractionalX(:,m)=masks(:,ids)*v/total; cumulative=cumsum(v)/total;
    for j=1:o.roundingCandidates
        if j==1, [~,at]=max(v); else, at=find(cumulative>=mod(j*.61803398875+m*.41421356237,1),1); end
        if isempty(at), at=numel(ids); end
        r.rounded{j}(:,m)=masks(:,ids(at));
    end
end
r.blockDual=lp.dual(1:M); r.columns=nnz(owner); r.pivots=lp.pivots;
end
