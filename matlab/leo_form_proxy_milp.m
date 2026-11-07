function model = leo_form_proxy_milp(data,lower,phase,s0)
%LEO_FORM_PROXY_MILP 第 13.3 节：直接线性化二次下界的完整周期 MILP。
% 输入：data、lower、fairness/throughput、固定 s0；输出稀疏 f/A/b/lb/ub/intcon。
% y_ijm=x_im*x_jm 用三个 McCormick 不等式；x 二元时 y 可保持连续。
% 周期模式服务矩阵保存 A_lower，serviceOffsetBits=-margin，QoS 右端已平移。
if nargin<4, s0 = 0; end
assert(any(strcmp(phase,{'fairness','throughput'})));
K = data.shape(1); M = data.shape(2); nx = K*M; pairs = zeros(0,3);
for m = 1:M
    ids = find(data.available(:,m));
    B = lower.bBits(ids,ids,m);
    mask = (B>0 | B.'>0) & bsxfun(@ne,data.beamIndex(ids,m),data.beamIndex(ids,m).');
    [a,b] = find(triu(mask,1));
    pairs = [pairs;ids(a),ids(b),repmat(m,numel(a),1)]; %#ok<AGROW>
end
np = size(pairs,1); isFair = strcmp(phase,'fairness'); n = nx+np+isFair;
pairColumns = nx+(1:np).';
forward = sub2ind([K,K,M],pairs(:,1),pairs(:,2),pairs(:,3));
reverse = sub2ind([K,K,M],pairs(:,2),pairs(:,1),pairs(:,3));
rows = [repmat((1:K).',M,1);pairs(:,1);pairs(:,2)];
cols = [(1:nx).';pairColumns;pairColumns];
values = [lower.aBits(:);-lower.bBits(forward);-lower.bBits(reverse)];
D = sparse(rows,cols,values,K,n);
i = pairs(:,1)+(pairs(:,3)-1)*K; j = pairs(:,2)+(pairs(:,3)-1)*K;
r = 3*(1:np).'-2; one = ones(np,1);
mc = sparse([r;r;r+1;r+1;r+2;r+2;r+2], ...
    [pairColumns;i;pairColumns;j;i;j;pairColumns], ...
    [one;-one;one;-one;one;one;-one],3*np,n);
rhs = zeros(3*np,1); rhs(3:3:end) = 1;
qos = -spdiags(1./data.qosTargetBits,0,K,K)*D;
if isFair, qos(:,n) = 1; qosRhs = zeros(K,1);
else, qosRhs = -s0*ones(K,1); end
[~,margin] = leo_service_adjustment(data);
qosRhs = qosRhs-margin./data.qosTargetBits;
% 代理要求 A_lower >= margin+s*q，是 G 约束的充分条件；s=0 时可更严格。
model.serviceOffsetBits = -margin;
model.objectiveConstant = 0;
if ~isFair, model.objectiveConstant = sum(margin)/data.referenceBits; end
model.A = [data.hard.A,sparse(size(data.hard.A,1),n-nx);mc;qos];
model.b = [data.hard.rhs;rhs;qosRhs];
model.lb = zeros(n,1); model.ub = [data.hard.upper;ones(n-nx,1)];
model.intcon = (1:nx).'; model.f = zeros(n,1);
if isFair, model.f(n) = -1; else, model.f = -full(sum(D,1)).'/data.referenceBits; end
model.serviceMatrixBits = D; model.pairs = pairs; model.nScheduleBits = nx;
model.sIndex = []; if isFair, model.sIndex = n; end
model.phase = phase; model.fairnessFloor = s0;
end
