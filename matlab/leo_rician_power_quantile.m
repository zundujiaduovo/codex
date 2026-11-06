function zeta = leo_rician_power_quantile(probability,kappa)
%LEO_RICIAN_POWER_QUANTILE R2 低分位；二分返回 CDF 上界不超过 eps 的下端。
% 接口标注：
% 输入：probability：尾部概率；kappa：线性 Rician 因子。
% 输出：zeta：保守非负功率低分位，不含 dB 单位。
% 适用当前单个 kappa 的模型；不是蒙特卡洛近似。过小风险明确报错。
assert(all(isfinite(probability(:))) && all(probability(:)>0 & probability(:)<1));
assert(isscalar(kappa) && isfinite(kappa) && kappa>=0 && kappa<=1e4);
if kappa==0
    zeta = -log1p(-probability);
    return;
end
[levels,~,map] = unique(probability(:));
values = zeros(size(levels));
for k = 1:numel(levels)
    target = levels(k);
    assert(target>128*eps*max(1,kappa), ...
        '风险低于当前数值分辨率；请调整风险/规模或使用更高精度。');
    lo = 0; hi = 1;
    [~,upper] = leo_rician_power_cdf(hi,kappa);
    while upper<target
        hi = 2*hi;
        [~,upper] = leo_rician_power_cdf(hi,kappa);
    end
    for iteration = 1:80
        mid = (lo+hi)/2;
        [~,upper] = leo_rician_power_cdf(mid,kappa);
        if upper<=target, lo = mid; else, hi = mid; end
        if hi-lo<=1e-12*max(1,hi), break; end
    end
    assert(lo>0,'正风险分位数数值下溢；不能据此声称正服务。');
    values(k) = lo;
end
zeta = reshape(values(map),size(probability));
end
