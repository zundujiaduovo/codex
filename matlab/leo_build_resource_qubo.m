function qubo = leo_build_resource_qubo(data,lower,m,weights,options)
%LEO_BUILD_RESOURCE_QUBO L4、Q1-Q4、M3：E=C+z'*Qsym*z，z=[用户位;松弛位]。
% 接口标注：
% 输入：data/lower：模型及下界；m：块号；weights：K×1；options：罚权/松弛选项。
% 输出：qubo：局部用户索引、A/B、对称/上三角 QUBO、常数与松弛位。
% 只删除物理不可用变量；同波束用成对冲突罚，不强制每波束激活。
if nargin<5, options = leo_method_options(); end
K = data.shape(1);
assert(isequal(size(weights),[K,1]) && all(isfinite(weights) & weights>=0));
assert(isscalar(m) && m==fix(m) && m>=1 && m<=data.shape(2));
ids = find(data.available(:,m)); n = numel(ids); L = data.maxStreams;
A = weights(ids).*lower.aBits(ids,m);
directed = bsxfun(@times,weights(ids),lower.bBits(ids,ids,m));
B = directed+directed.';
B(1:n+1:end) = 0;
assert(all(isfinite(A)) && all(isfinite(B(:))) && all(B(:)>=0));
beams = data.beamIndex(ids,m);
sameBeam = bsxfun(@eq,beams,beams.');
sameBeam(1:n+1:end) = false;
redundant = numel(unique(beams))<=L;
useCapacity = ~(options.removeRedundantCapacity && redundant);
if useCapacity, d = 2.^(0:ceil(log2(L+1))-1).'; else, d = zeros(0,1); end
N = n+numel(d);
Q = zeros(N,N); Q(1:n,1:n) = -diag(A)+B/2;
Amax = max([0;A]);
if Amax>0, penalty = options.penaltyFactor*Amax; else, penalty = 1; end
Q(1:n,1:n) = Q(1:n,1:n)+penalty*double(sameBeam)/2;
C = 0;
if useCapacity
    c = [ones(n,1);d];
    Q = Q+penalty*(c*c.'-2*L*diag(c));
    C = penalty*L^2;
end
qubo.userIds = ids; qubo.beamIndex = beams;
qubo.nUsers = n; qubo.nBits = N; qubo.maxStreams = L;
qubo.A = A; qubo.B = B;
qubo.slackWeights = d;
qubo.capacityIncluded = useCapacity;
qubo.capacityRedundant = redundant;
qubo.capacityPenalty = penalty*useCapacity;
qubo.beamPenalty = penalty;
qubo.Qsym = Q;
qubo.Qupper = diag(diag(Q))+2*triu(Q,1);
qubo.constant = C;
end
