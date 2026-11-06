function c = leo_check_codebook_coverage(p,cb)
%LEO_CHECK_CODEBOOK_COVERAGE 对固定扫描域抽样检查真实量化方向图。
% 接口标注：
% 输入：p：扫描验证网格、覆盖门槛；cb：实际有限码本。
% 输出：c：抽样最优增益、空洞比例；不是连续扫描域证明。
axisU = linspace(-sin(p.array.scanMaxDeg*pi/180), ...
    sin(p.array.scanMaxDeg*pi/180),p.array.coverageGridSize);
[ux,uy] = ndgrid(axisU,axisU);
mask = ux.^2+uy.^2<=sin(p.array.scanMaxDeg*pi/180)^2;
ux = ux(mask).'; uy = uy(mask).';
c.directionArray = [ux;uy;sqrt(max(0,1-ux.^2-uy.^2))];
a = leo_array_response(p,c.directionArray);
c.bestGain = max(abs(a'*cb.F).^2,[],2);
c.belowThreshold = c.bestGain<p.coverage.minGain;
c.holeFraction = mean(c.belowThreshold);
c.minSampledGain = min(c.bestGain);
% 返回空洞而不静默修改码本；不等同于连续扫描域覆盖证明。
end
