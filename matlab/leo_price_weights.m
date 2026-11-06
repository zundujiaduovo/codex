function [weights,sAux] = leo_price_weights(data,lambda,phase,s0)
%LEO_PRICE_WEIGHTS L3-L5、V3：阶段 1 的 s 辅助解与两阶段非负用户权重。
% 接口标注：
% 输入：data：需求及 Dref；lambda：K×1 非负价格；phase/s0：阶段和门槛。
% 输出：weights：K×1 服务权重（1/bit）；sAux：公平辅助解或固定门槛。
if nargin<4, s0 = 0; end
assert(isequal(size(lambda),[data.shape(1),1]) && all(isfinite(lambda) & lambda>=0));
assert(any(strcmp(phase,{'fairness','throughput'})));
weights = lambda./data.qosTargetBits;
if strcmp(phase,'fairness')
    sAux = double(sum(lambda)<=1);   % 等于 1 时 [0,1] 中任何值均可
else
    weights = weights+1/data.referenceBits;
    sAux = s0;
end
end
