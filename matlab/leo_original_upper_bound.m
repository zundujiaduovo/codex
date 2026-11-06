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
if strcmp(phase,'fairness')
    bound.value = min(1,max(0,1-sum(lambda))+sum(bound.resource));
else
    bound.value = sum(bound.resource)-s0*sum(lambda);
end
bound.kind = cache.kind;
bound.lambda = lambda;
bound.fairnessFloor = s0;
end
