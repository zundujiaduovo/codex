function bound = leo_original_upper_bound(data,cache,lambda,phase,s0)
%LEO_ORIGINAL_UPPER_BOUND E4/E6 + UB1，有效原问题上界，独立于 SB 近似质量。
% 接口标注：
% 输入：data/cache：完整模型和 UB1 缓存；lambda：非负价格；phase/s0。
% 输出：bound：原始公平或归一化吞吐有效上界、资源项与价格。
if nargin<5, s0 = 0; end
[weights,~] = leo_price_weights(data,lambda,phase,s0);
M = data.shape(2);
bound.resource = zeros(1,M);
for m = 1:M
    ids = find(data.available(:,m));
    beams = unique(data.beamIndex(ids,m));
    for n = 1:min(data.maxStreams,numel(beams))
        v = weights.*cache.serviceByCardinality(:,m,n);
        beamValues = zeros(numel(beams),1);
        for b = 1:numel(beams)
            beamValues(b) = max(v(ids(data.beamIndex(ids,m)==beams(b))));
        end
        beamValues = sort(beamValues,'descend');
        bound.resource(m) = max(bound.resource(m),sum(beamValues(1:n)));
    end
end
[~,margin] = leo_service_adjustment(data);
penalty = sum(lambda(:).*margin./data.qosTargetBits);
if strcmp(phase,'fairness')
    % 正公平必有 A_i>=margin_i+s*q_i；若正公平不可行，最优值为零。
    bound.value = max(0,min(1,max(0,1-sum(lambda))+sum(bound.resource)-penalty));
elseif s0>0 || ~any(margin>0)
    bound.value = sum(bound.resource)-s0*sum(lambda)-penalty-sum(margin)/data.referenceBits;
else
    % 零门槛允许 A_i<margin_i，不能错误地从截断服务总和扣全体 margin。
    bound.value = sum(bound.resource);
end
bound.kind = cache.kind;
bound.lambda = lambda;
bound.fairnessFloor = s0;
end
