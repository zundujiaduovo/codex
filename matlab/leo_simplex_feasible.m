function result = leo_simplex_feasible(A,b,c,basis,budget,maxPivots)
%LEO_SIMPLEX_FEASIBLE 原始可行基上的 Bland 修正单纯形；不依赖优化工具箱。
% max c'*z, A*z=b,z>=0。只用于证书主问题；外部仍精确定价复核上界。
if nargin<6, maxPivots=5000; end
n=size(A,2); result.status='pivot_limit'; pivots=0;
for iteration=1:maxPivots+1
    B=A(:,basis);
    if rcond(B)<1e-13, result.status='ill_conditioned_basis'; break; end
    xb=B\b; dual=B'\c(basis);
    if min(xb)<-1e-7, result.status='lost_primal_feasibility'; break; end
    reduced=c-A'*dual; reduced(basis)=0;
    entering=find(reduced>1e-8,1,'first');
    if isempty(entering), result.status='optimal'; break; end
    if iteration>maxPivots, break; end
    if mod(iteration,8)==1 && toc(budget.timer)>=budget.seconds
        result.status='time_limit'; break;
    end
    direction=B\A(:,entering); eligible=find(direction>1e-10);
    if isempty(eligible), result.status='numerical_unbounded'; break; end
    ratio=max(0,xb(eligible))./direction(eligible); best=min(ratio);
    tied=eligible(ratio<=best+1e-10*max(1,abs(best)));
    [~,j]=min(basis(tied)); leaving=tied(j);
    basis(leaving)=entering; pivots=pivots+1;
end
B=A(:,basis); xb=B\b; dual=B'\c(basis);
result.x=zeros(n,1); result.x(basis)=max(0,xb);
result.dual=dual; result.basis=basis; result.objective=c'*result.x;
result.pivots=pivots;
result.feasible=min(xb)>=-1e-7 && norm(A*result.x-b,inf)<=1e-6;
end
