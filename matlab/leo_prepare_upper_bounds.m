function cache = leo_prepare_upper_bounds(data)
%LEO_PREPARE_UPPER_BOUNDS UB1：按组基数 n，取其他波束中最小 n-1 个干扰。
% 接口标注：
% 输入：data：完整物理域、用户—波束干扰及固定资源。
% 输出：cache：K×M×L 按组基数的原始服务上界 bit。
% 每基本槽分别放松；没有枚举用户组，没有使用 SB 内层值充当上界。
% n=1 即无干扰单用户上界。所有物理可用波束均参与。
K = data.shape(1); M = data.shape(2); L = data.maxStreams;
[scale,~] = leo_service_adjustment(data);
cache.serviceByCardinality = zeros(K,M,L);
cache.nBeams = zeros(1,M);
for m = 1:M
    ids = find(data.available(:,m));
    beams = unique(data.beamIndex(ids,m));
    cache.nBeams(m) = numel(beams);
    nMax = min(L,numel(beams));
    for i = ids.'
        others = beams(beams~=data.beamIndex(i,m));
        bits = zeros(1,nMax);
        for t = find(data.slotToResource==m)
            if data.dataDurationS(t)<=0, continue; end
            powers = sort(reshape(data.design.beamPowerW(i,others,t),1,[]));
            interference = [0,cumsum(powers)];
            sinr = data.design.signalW(i,t)./(data.design.noiseW(i,t)+interference(1:nMax));
            bits = bits+data.dataDurationS(t)*data.bandwidthHz*scale(i)*log1p(sinr)/log(2);
        end
        cache.serviceByCardinality(i,m,1:nMax) = reshape(bits,1,1,[]);
    end
end
cache.kind = 'UB1: full-domain cardinality bound on ORIGINAL design service';
end
