function [cdfValue,cdfUpper] = leo_rician_power_cdf(z,kappa)
%LEO_RICIAN_POWER_CDF R2：归一化 Rician 功率的 CDF，无统计工具箱依赖。
% 接口标注：
% 输入：z：非负归一化功率；kappa：线性 Rician 因子。
% 输出：cdfValue/cdfUpper：CDF 近似及带截断余项的上界。
% 2(1+kappa)Z ~ ncx2(2,2*kappa)。用 Poisson(kappa) 混合 Gamma(j+1,1)。
% cdfUpper 加上截断尾质量和浮点裕量，用于保守数值求分位数。
assert(isscalar(kappa) && isfinite(kappa) && kappa>=0 && kappa<=1e4);
assert(all(isfinite(z(:))) && all(z(:)>=0));
if kappa==0
    cdfValue = -expm1(-z);
    cdfUpper = cdfValue;
    return;
end
J = ceil(kappa+12*sqrt(kappa+1)+40);
j = 0:J;
weight = exp(-kappa+j*log(kappa)-gammaln(j+1));
% 未对截断权重重新归一化，以免改变分布。
guard = 64*eps*max(1,kappa);
tail = max(0,1-sum(weight))+guard;
cdfValue = zeros(size(z));
for k = 1:numel(z)
    cdfValue(k) = sum(weight.*gammainc((1+kappa)*z(k),j+1,'lower'));
end
cdfUpper = min(1,cdfValue+tail);
cdfValue = min(1,max(0,cdfValue));
cdfUpper(z==0) = 0;                 % F_Z(0)=0 可精确判定
end
