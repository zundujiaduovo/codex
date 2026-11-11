function r=leo_sparse_lp_dual(model,iterations)
% 无工具箱的有界LP原始-对偶迭代；每次报告经盒残差补偿的有效对偶界。
% 有限迭代只提供上界，不宣称LP最优。
if nargin<2, iterations=1500; end
A=model.A; Ae=model.Aeq; b=model.b; be=model.beq; c=model.c;
scale=max(1,full(sum(abs(A),2))); escale=max(1,full(sum(abs(Ae),2)));
As=spdiags(1./scale,0,numel(scale),numel(scale))*A;
Es=spdiags(1./escale,0,numel(escale),numel(escale))*Ae;
operator=[As;Es]; L=sqrt(max(full(sum(abs(operator),1)))*max(full(sum(abs(operator),2))));
step=.95/max(1,L); x=model.lb; extrapolated=x; u=zeros(size(b)); v=zeros(size(be)); upper=Inf; bestU=u; bestV=v;
for k=1:iterations
    u=max(0,u+step*(As*extrapolated-b./scale)); v=v+step*(Es*extrapolated-be./escale);
    previous=x; x=min(model.ub,max(model.lb,x+step*(c-As.'*u-Es.'*v))); extrapolated=2*x-previous;
    if mod(k,25)~=0 && k~=iterations, continue; end
    uu=u./scale; vv=v./escale; residual=c-A.'*uu-Ae.'*vv;
    terms=max(residual,0).*model.ub+min(residual,0).*model.lb;
    value=b.'*uu+be.'*vv+sum(terms)+model.constant;
    guard=1e-8*max(1,sum(abs(b.*uu))+sum(abs(be.*vv))+sum(abs(terms))+abs(model.constant));
    if value+guard<upper, upper=value+guard; bestU=uu; bestV=vv; end
end
r=struct('available',true,'status',sprintf('built-in PDHG %d iterations; dual bound, LP optimality unproved',iterations), ...
 'upper',upper,'primalValue',c.'*x+model.constant, ...
 'dualResidual',max(abs(c-A.'*bestU-Ae.'*bestV)),'backend','built-in sparse primal-dual','solution',x,'floorMultiplierSum',NaN);
if isfield(model,'floorRows'), r.floorMultiplierSum=sum(bestU(model.floorRows)); end
end
