function [levels,mass] = leo_fading_floor_distribution(referenceFade,kappa,nLevels)
%LEO_FADING_FLOOR_DISTRIBUTION 保守量化 U=min(1,Z/z*)；CDF 上界向低服务移动质量。
assert(isscalar(referenceFade) && referenceFade>0 && isfinite(referenceFade));
assert(isscalar(nLevels) && nLevels>=1 && nLevels==fix(nLevels));
levels = (0:nLevels)/nLevels;
[~,cdfUpper] = leo_rician_power_cdf(referenceFade*levels(2:end),kappa);
assert(all(diff(cdfUpper)>=-1e-13));
for j=2:numel(cdfUpper), cdfUpper(j)=max(cdfUpper(j),cdfUpper(j-1)); end
mass = [cdfUpper(1),diff(cdfUpper),1-cdfUpper(end)];
assert(all(mass>=0) && abs(sum(mass)-1)<1e-12);
end
