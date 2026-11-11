function r=leo_verified_lp_upper(model)
% 对max c'z+constant的连续LP，以任意对偶乘子和有限盒残差重算安全上界。
% 绝不把未收敛的原始LP目标当上界。优先linprog，其次GLPK。
A=model.A; b=model.b; Ae=model.Aeq; be=model.beq; c=model.c;
r=struct('available',false,'status','LP backend unavailable: requires linprog or GLPK', ...
 'upper',Inf,'primalValue',NaN,'dualResidual',NaN,'backend','','solution',[],'floorMultiplierSum',NaN);
dual=[];
try
 if exist('linprog','file')~=0
    settings=optimoptions('linprog','Display','none','MaxIterations',100000);
    [x,f,flag,out,lambda]=linprog(-c,A,b,Ae,be,model.lb,model.ub,settings); %#ok<ASGLU>
    r.backend='linprog'; r.status=sprintf('linprog_exit_%d',flag);
    if isfield(lambda,'ineqlin'), dual=[lambda.ineqlin;lambda.eqlin]; end
 elseif exist('glpk','file')~=0
    types=[repmat('U',size(A,1),1);repmat('S',size(Ae,1),1)];
    parameters=struct('msglev',0,'itlim',100000,'presol',1);
    [x,f,err,extra]=glpk(-c,[A;Ae],[b;be],model.lb,model.ub,types,repmat('C',numel(c),1),1,parameters); %#ok<ASGLU>
    r.backend='GLPK'; r.status=sprintf('GLPK_error_%d_status_%d',err,extra.status);
    if isfield(extra,'lambda'), dual=extra.lambda; end
 else, r=leo_sparse_lp_dual(model); return;
 end
 r.available=true; r.solution=x;
 if ~isempty(x) && all(isfinite(x)), r.primalValue=c.'*x+model.constant; end
 if isempty(dual) || any(~isfinite(dual))
    status=r.status; r=leo_sparse_lp_dual(model); r.status=[status,'; fallback: ',r.status]; return;
 end
 for sign=[1,-1]
    u=max(0,sign*dual(1:size(A,1))); v=sign*dual(size(A,1)+1:end);
    residual=c-A.'*u-Ae.'*v;
    terms=max(residual,0).*model.ub+min(residual,0).*model.lb;
    value=b.'*u+be.'*v+sum(terms)+model.constant;
    % Outward floating guard scales with the arithmetic, not with the primal objective.
    guard=1e-8*max(1,sum(abs(b.*u))+sum(abs(be.*v))+sum(abs(terms))+abs(model.constant));
    if value+guard<r.upper
        r.upper=value+guard; r.dualResidual=max(abs(residual));
        if isfield(model,'floorRows'), r.floorMultiplierSum=sum(u(model.floorRows)); end
    end
 end
catch err
 r=leo_sparse_lp_dual(model); r.status=['External solver failed: ',err.message,'; ',r.status];
end
end
