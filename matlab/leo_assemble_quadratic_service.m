function q = leo_assemble_quadratic_service(data,alphaBps,omegaBpsPerW)
%LEO_ASSEMBLE_QUADRATIC_SERVICE T5-T6：a_i*x_i - sum_{j~=i}b_ij*x_i*x_j。
% 接口标注：
% 输入：data：模型；alphaBps/omegaBpsPerW：K×T 仿射速率系数。
% 输出：q：K×M aBits、K×K×M 有向 bBits，逐基本槽精确累加。
% b 是有向用户干扰损失，通常不对称；对角严格为零，不新增二进制变量。
K = data.shape(1); M = data.shape(2);
assert(isequal(size(alphaBps),size(data.design.signalW)));
assert(isequal(size(omegaBpsPerW),size(data.design.signalW)));
assert(all(isfinite(alphaBps(:))) && all(isfinite(omegaBpsPerW(:))) && all(omegaBpsPerW(:)>=0));
q.aBits = zeros(K,M); q.bBits = zeros(K,K,M);
for t = 1:numel(data.slotToResource)
    if data.dataDurationS(t)<=0, continue; end
    m = data.slotToResource(t);
    ids = find(data.available(:,m));
    C = zeros(K,K);
    C(:,ids) = data.design.beamPowerW(:,data.beamIndex(ids,m),t);
    C(~data.available(:,m),:) = 0;
    C(1:K+1:end) = 0;
    q.aBits(:,m) = q.aBits(:,m)+data.dataDurationS(t)*alphaBps(:,t).*data.available(:,m);
    q.bBits(:,:,m) = q.bBits(:,:,m)+data.dataDurationS(t)*bsxfun(@times,omegaBpsPerW(:,t),C);
end
end
