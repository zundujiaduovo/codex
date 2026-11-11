function r=leo_v14_coupled_bound(report,phase,floorValue)
% 原速率弦线上界 + 共用x/y/波束选择 + McCormick + 容量RLT。
% LP松弛原问题，不能使用切线下界构造上界。
if nargin<3, floorValue=0; end
started=tic;
d=report.problemData; problem=struct('data',d,'evaluate',@(x)leo_evaluate_service(d,x));
proxy=leo_v12_build_service_surrogates(problem,'minimax');
model=leo_form_proxy_milp(d,proxy.upper,phase,floorValue,true);
K=d.shape(1); M=d.shape(2); nx=K*M; n=numel(model.f); np=size(model.pairs,1);
P=sparse([model.pairs(:,1)+(model.pairs(:,3)-1)*K;model.pairs(:,2)+(model.pairs(:,3)-1)*K], ...
 repmat((1:np).',2,1),ones(2*np,1),nx,np);
total=kron(speye(M),ones(K));
upper=[-(d.maxStreams-1)*speye(nx),P,sparse(nx,n-nx-np)];
lower=[total+(d.maxStreams-1)*speye(nx),-P,sparse(nx,n-nx-np)];
model.A=[model.A;upper;lower]; model.b=[model.b;zeros(nx,1);d.maxStreams*ones(nx,1)];
% z_bm=sum of eligible user choices for a common physical beam; one common pair variable
% simultaneously enters both users' interference expressions.
B=numel(d.hard.beamRows); nOld=n;
model.A=[model.A,sparse(size(model.A,1),B)];
model.Aeq=[-d.hard.A(d.hard.beamRows,:),sparse(B,nOld-nx),speye(B)]; model.beq=zeros(B,1);
model.lb=[model.lb;zeros(B,1)]; model.ub=[model.ub;ones(B,1)];
model.c=[-model.f;zeros(B,1)]; model.constant=-model.objectiveConstant;
model.floorRows=size(d.hard.A,1)+3*np+(1:K);
if strcmp(phase,'throughput') && floorValue==0
    % At zero floor G=[A-c]+ is clipped: drop the margin subtraction/constraints safely.
    model.constant=0; qosRows=size(d.hard.A,1)+3*np+(1:K);
    model.b(qosRows)=0;
end
lp=leo_verified_lp_upper(model); value=lp.upper;
if strcmp(phase,'fairness'), value=max(0,value); else, value=max(0,value*d.referenceBits); end
r=struct('kind','Original chord + common choices + McCormick + capacity RLT', ...
 'phase',phase,'floor',floorValue,'upper',value,'lp',rmfield(lp,'solution'), ...
 'variables',numel(model.c),'constraints',size(model.A,1),'commonBeamVariables',B, ...
 'sharedProducts',np,'floorConstraints',K,'elapsedSeconds',toc(started), ...
 'clippedZeroFloor',strcmp(phase,'throughput') && floorValue==0, ...
 'scope','Global ORIGINAL relaxation upper, attainable value not established; throughput is conditional on the stated floor.');
end
