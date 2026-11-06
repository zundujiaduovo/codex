function estimate = leo_exhaustive_size(data)
%LEO_EXHAUSTIVE_SIZE 合法组数 Gm 与完整日程数 prod(Gm)，不生成候选组。
% 接口标注：
% 输入：data：每个资源的候选、波束归属与人数上限。
% 输出：estimate：合法组数、完整组合数、log10 规模与双精度精确计数标志。
% 若波束 b 有 nb 个用户，Gm=sum_{l=0}^L [z^l] prod_b(1+nb*z)。
M = data.shape(2);
estimate.groupsPerResource = zeros(1,M);
estimate.log10Groups = zeros(1,M);
estimate.activeBeamCounts = zeros(1,M);
for m = 1:M
    ids = data.beamIndex(data.available(:,m),m);
    codes = unique(ids);
    degree = min(data.maxStreams,numel(codes));
    coefficient = [1,zeros(1,degree)];
    logCoefficient = [0,-Inf(1,degree)];
    for beam = codes.'
        count = nnz(ids==beam);
        for l = degree:-1:1
            coefficient(l+1) = coefficient(l+1)+count*coefficient(l);
            a = logCoefficient(l+1); b = log(count)+logCoefficient(l);
            if isinf(a) && isinf(b), continue; end
            logCoefficient(l+1) = max(a,b)+log1p(exp(-abs(a-b)));
        end
    end
    estimate.groupsPerResource(m) = sum(coefficient);
    top = max(logCoefficient);
    estimate.log10Groups(m) = (top+log(sum(exp(logCoefficient-top))))/log(10);
    estimate.activeBeamCounts(m) = numel(codes);
end
estimate.totalSchedules = prod(estimate.groupsPerResource);
estimate.log10Schedules = sum(estimate.log10Groups);
estimate.countExactInDouble = all(estimate.groupsPerResource<=flintmax) && ...
    estimate.totalSchedules<=flintmax;
estimate.includesEmptyGroup = true;
estimate.resources = M;
end
