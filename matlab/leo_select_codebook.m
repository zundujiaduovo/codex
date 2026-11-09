function cb = leo_select_codebook(p,cb)
%LEO_SELECT_CODEBOOK 在用户生成前选定 NB 个码字，不依赖用户/日程/价格。
% 接口标注：
% 输入：p：目标码字数；cb：量化去重后的固定候选码本。
% 输出：cb：在用户产生前离线冻结的子码本。
% 固定扫描域上贪心增加达到 gmin 的验证点数；并列时最大化增益提升。
% 这只是离线字典子集规则，不声称最优覆盖；空洞由后续检查如实报告。
N = p.array.nBeams;
assert(N<=cb.nBeams,'合法去重候选不足 NB，请增大固定网格或降低 NB。');
cb.candidateCount = cb.nBeams;
if N==cb.nBeams
    selected = 1:N;
else
    bound = sin(p.array.scanMaxDeg*pi/180);
    [ux,uy] = ndgrid(linspace(-bound,bound,p.array.coverageGridSize));
    valid = ux.^2+uy.^2<=bound^2;
    ux = ux(valid).'; uy = uy(valid).';
    a = leo_array_response(p,[ux;uy;sqrt(max(0,1-ux.^2-uy.^2))]);
    gain = abs(a'*cb.F).^2;
    % 仅离线选择分数取固定精度，实际物理增益/覆盖判据保留原始值。
    gain=round(gain*1e12)/1e12;
    best = zeros(size(gain,1),1);
    selected = zeros(1,N);
    used = false(1,cb.nBeams);
    for k = 1:N
        newCoverage = sum(bsxfun(@and,gain>=p.coverage.minGain,best<p.coverage.minGain),1);
        newCoverage(used) = -Inf;
        candidates = find(newCoverage==max(newCoverage));
        improvement = sum(bsxfun(@max,gain(:,candidates),best)-best,1);
        j = leo_stable_argmax(improvement,1e-10);
        selected(k) = candidates(j);
        used(selected(k)) = true;
        best = max(best,gain(:,selected(k)));
    end
    selected = sort(selected);       % 保留原网格字典序，稳定编号
end
cb.selectedCandidateIndex = selected;
cb.selectionRule='coverage_grid_quantized_1e12_ties_1e10_v6';
cb.F = cb.F(:,selected);
cb.phaseIndex = cb.phaseIndex(:,selected);
cb.directionArray = cb.directionArray(:,selected);
cb.gridIndex = cb.gridIndex(:,selected);
cb.centerGain = cb.centerGain(selected);
cb.nBeams = N;
end
