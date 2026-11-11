function p = leo_validate_parameters(p)
%LEO_VALIDATE_PARAMETERS 检查物理约束，并统一更新所有派生参数。
% 接口标注：
% 输入：p：原始参数结构。
% 输出：p：校验后参数，需求统一为 K×1，并更新所有派生量。
positive = [p.constants.c,p.constants.kB,p.earth.aM,p.earth.mu, ...
    p.system.carrierHz,p.system.bandwidthHz,p.system.streamPowerW, ...
    p.system.maxPowerW,p.time.slotDurationS,p.orbit.altitudeM, ...
    p.channel.systemTemperatureK];
assert(all(isfinite(positive)) && all(positive>0), '物理量必须有限且为正。');
counts = [p.system.K,p.system.nRF,p.system.maxStreams,p.time.nSlots, ...
    p.time.blockSlots,p.array.nX,p.array.nY,p.array.gridOversampling, ...
    p.array.phaseBits,p.array.coverageGridSize,p.array.nBeams];
assert(all(isfinite(counts)) && all(counts>=1) && all(counts==fix(counts)), ...
    '用户数、槽数、阵元数和网格参数必须是正整数。');
assert(p.array.coverageGridSize>=3 && p.array.phaseBits<=16);
assert(p.earth.flattening>=0 && p.earth.flattening<1);
assert(numel(p.array.spacingWavelength)==2 && ...
    all(p.array.spacingWavelength>0 & p.array.spacingWavelength<=0.5));
assert(p.array.scanMaxDeg>0 && p.array.scanMaxDeg<90);
assert(p.coverage.minElevationDeg>=0 && p.coverage.minElevationDeg<=90);
assert(isfinite(p.coverage.maxArrayLossDb) && p.coverage.maxArrayLossDb>=0);
assert(p.time.baseOverheadS>=0 && p.time.configOverheadS>=0 && ...
    p.time.baseOverheadS+p.time.configOverheadS<=p.time.slotDurationS, ...
    '净数据时间不能为负。');
assert(p.users.radiusM>=0 && p.users.radiusM<pi*p.earth.aM);
if ~isfield(p.users,'layout'), p.users.layout = 'random_cap'; end
assert(any(strcmp(p.users.layout,{'reference32','random_cap'})));
assert(abs(p.users.centerLatDeg)<=90 && p.users.altitudeM>=0);
assert(p.channel.extraLossDb>=0 && isfinite(p.channel.extraLossDb));
assert(all(isfinite([p.channel.elementGainDbi,p.channel.receiveGainDbi, ...
    p.channel.ricianKDb,p.orbit.inclinationDeg,p.orbit.raanDeg, ...
    p.orbit.initialArgumentDeg,p.orbit.earthAngleAtEpochDeg])));
assert(isscalar(p.seed) && p.seed>=0 && p.seed<=2^32-1 && p.seed==fix(p.seed));
p.array.nElements = p.array.nX*p.array.nY;
p.array.gridX = p.array.gridOversampling*p.array.nX;
p.array.gridY = p.array.gridOversampling*p.array.nY;
p.system.wavelengthM = p.constants.c/p.system.carrierHz;
p.array.spacingM = p.array.spacingWavelength*p.system.wavelengthM;
p.coverage.minGain = 10^(-p.coverage.maxArrayLossDb/10);
p.channel.ricianK = 10^(p.channel.ricianKDb/10);
p.earth.e2 = p.earth.flattening*(2-p.earth.flattening);
assert(p.system.maxStreams<=min(p.system.nRF,p.array.nElements));
assert(p.system.maxStreams<=p.array.nBeams,'必须满足 L<=NB。');
assert(p.system.maxStreams*p.system.streamPowerW<=p.system.maxPowerW, ...
    '必须满足 L*p0 <= Pmax。');
q = p.system.qosTargetBits;
assert((isscalar(q) || numel(q)==p.system.K) && all(isfinite(q(:))) && all(q(:)>0));
if isscalar(q), q = repmat(q,p.system.K,1); end
p.system.qosTargetBits = q(:);
assert(isscalar(p.statistics.totalRisk) && isfinite(p.statistics.totalRisk) && ...
    p.statistics.totalRisk>0 && p.statistics.totalRisk<1);
% 未携带新字段的历史参数继续使用旧模型，避免静默改变旧实验口径。
if ~isfield(p.statistics,'serviceModel'), p.statistics.serviceModel = 'slot_union'; end
assert(any(strcmp(p.statistics.serviceModel,{'slot_union','periodic_chernoff','periodic_multilevel'})));
if any(strcmp(p.statistics.serviceModel,{'periodic_chernoff','periodic_multilevel'}))
    assert(isfield(p.statistics,'independentSlots') && ...
        isequal(p.statistics.independentSlots,true), ...
        '周期 Chernoff 证书要求用户内基本槽独立；相关衰落请使用 slot_union。');
    v = [p.statistics.goodFadeThreshold,p.statistics.chernoffTilt];
    assert(numel(v)==2 && all(isfinite(v)) && all(v>0));
end
if strcmp(p.statistics.serviceModel,'periodic_multilevel')
    assert(isscalar(p.statistics.fadingLevels) && p.statistics.fadingLevels>=1 && p.statistics.fadingLevels==fix(p.statistics.fadingLevels));
    for field={'referenceFadeGrid','tiltGrid'}
        values=p.statistics.(field{1});
        assert(isrow(values) && ~isempty(values) && all(isfinite(values)) && all(values>0));
    end
end
if ~isfield(p.problem,'requireFullQos'), p.problem.requireFullQos=false; end
if ~isfield(p.problem,'objectiveMode'), p.problem.objectiveMode='full_qos_sum'; end
assert(any(strcmp(p.problem.objectiveMode,{'lexicographic_max_min','full_qos_sum'})),'Unknown objective mode.');
assert(isscalar(p.problem.requireFullQos) && any(p.problem.requireFullQos==[0,1]));
if isempty(p.problem.referenceBits)
    p.problem.referenceBits = sum(q);
end
assert(isscalar(p.problem.referenceBits) && isfinite(p.problem.referenceBits) && ...
    p.problem.referenceBits>0,'D_ref 必须是与决策无关的正数。');
assert(isscalar(p.problem.feasibilityTolerance) && ...
    isfinite(p.problem.feasibilityTolerance) && p.problem.feasibilityTolerance>0);
if ~isfield(p,'exhaustive'), p.exhaustive = struct(); end
p.exhaustive = leo_exhaustive_options(p.exhaustive);
if ~isfield(p,'surrogate'), p.surrogate.referenceMode = 'minimax'; end
assert(any(strcmp(p.surrogate.referenceMode,{'minimax','zero','current_schedule'})));
if ~isfield(p,'method'), p.method = struct(); end
p.method = leo_method_options(p.method);
end
