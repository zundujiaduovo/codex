function o = leo_method_options(overrides)
%LEO_METHOD_OPTIONS 配置 A：全物理候选域、两阶段拉格朗日 + ballistic SB。
% 接口标注：
% 输入：overrides：可选算法参数覆盖结构。
% 输出：o：校验后的价格、SB、修复、预算、内层求解器和切点设置。
% 步长/SB 参数是可调实验起点，不代表收敛或最优保证。
o.enabled = false;
o.seed = 20261105;
o.innerSolver = 'sb';              % sb / local / miqp，同一价格与验收机制
o.referenceMode = 'minimax';        % 未传入 proxy 时使用；zero/current_schedule 用于消融
o.throughputReferenceMode = 'current_schedule'; % 吞吐阶段参考点独立设置，消融不再失效
o.localRestarts = 16;
o.fairnessRounds = 24;
o.throughputRounds = 12;
o.maxSeconds = 60;                 % 求解总预算，含初始化；物理建模另计
o.fairnessBudgetFraction = 0.7;
o.fairnessStep = 0.25;
o.throughputStep = 0.15;
o.stepExponent = 0.6;
o.refreshEvery = 6;                % 0: 阶段内固定切点；阶段 2 始终先相切
o.gapTolerance = 1e-7;             % 公平或归一化吞吐的有效上下界差
o.sbSteps = 250;
o.sbTrajectories = 16;
o.sbTimeStep = 0.15;
o.sbCoupling = 1;
o.sbCheckpoint = 10;
o.sbPerturbedSeeds = 4;             % 旧组附近的扰动轨迹，其余轨迹仍随机
o.candidatePoolSize = 6;            % 保留旧组、代理最佳和不同的合法候选
o.jointStagnationRounds = 8;        % 连续无原目标改进后的两块候选组合触发门槛
o.jointPairsPerTrigger = 3;
o.jointMaxCombinations = 49;
o.jointCandidateSearch = false;     % 组合候选验收；不是联合 Ising 动力学
o.originalSearchRounds = 10000;     % Tabu/exchange 也可通过选项延长
o.penaltyFactor = 1.1;             % 严格 > 1，随当前权重重新计算
o.removeRedundantCapacity = true;
o.polishMoves = 6;                 % 修复后的资源二次收益局部改进
o.randomInitialSchedules = 3;
o.recoveryEvaluations = 160;       % 每轮每个起点的原始服务动作评价预算
o.recoveryPasses = 4;
o.crossResourceFraction = 0.25;
o.blockwiseOriginalAccept = false;  % 按原周期目标逐块验收，阶段 2 保留 QoS 门槛
o.verbose = true;
if nargin>0
    assert(isstruct(overrides) && isscalar(overrides));
    [overrides,iterationFields]=leo_extract_iteration_options(overrides);
    if isfield(overrides,'stopping')
        stopping=leo_stopping_options(overrides.stopping); overrides=rmfield(overrides,'stopping');
    end
    if isfield(overrides,'audit')
        audit=leo_audit_options(overrides.audit); overrides=rmfield(overrides,'audit');
    end
    if isfield(overrides,'fastPolish')
        fastPolish=overrides.fastPolish; assert(isscalar(fastPolish) && any(fastPolish==[0,1]));
        overrides=rmfield(overrides,'fastPolish');
    end
    names = fieldnames(overrides);
    for j = 1:numel(names)
        assert(isfield(o,names{j}),['未知方法参数: ',names{j}]);
        o.(names{j}) = overrides.(names{j});
    end
end
assert(ischar(o.innerSolver) && any(strcmp(o.innerSolver,{'sb','local','miqp'})));
assert(ischar(o.referenceMode) && any(strcmp(o.referenceMode,{'minimax','zero','current_schedule'})));
assert(any(strcmp(o.throughputReferenceMode,{'minimax','zero','current_schedule'})));
numericFields = setdiff(fieldnames(o),{'enabled','removeRedundantCapacity','verbose','innerSolver','referenceMode','throughputReferenceMode','blockwiseOriginalAccept','jointCandidateSearch'});
for j = 1:numel(numericFields)
    v = o.(numericFields{j});
    assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v), ...
        ['方法参数须为有限实标量: ',numericFields{j}]);
end
flags = {'enabled','removeRedundantCapacity','verbose','blockwiseOriginalAccept','jointCandidateSearch'};
for j = 1:numel(flags)
    v = o.(flags{j});
    assert(isscalar(v) && (islogical(v) || isnumeric(v)) && isfinite(v) && (v==0 || v==1));
    o.(flags{j}) = logical(v);
end
integers = [o.fairnessRounds,o.throughputRounds,o.refreshEvery,o.sbSteps, ...
    o.sbTrajectories,o.sbCheckpoint,o.polishMoves,o.randomInitialSchedules, ...
    o.recoveryEvaluations,o.recoveryPasses,o.seed,o.localRestarts,o.sbPerturbedSeeds, ...
    o.candidatePoolSize,o.jointStagnationRounds,o.jointPairsPerTrigger,o.jointMaxCombinations,o.originalSearchRounds];
assert(all(isfinite(integers)) && all(integers>=0 & integers==fix(integers)));
assert(o.sbSteps>=1 && o.sbTrajectories>=1 && o.sbCheckpoint>=1 && o.recoveryPasses>=1);
assert(o.localRestarts>=1);
assert(o.candidatePoolSize>=2 && o.jointStagnationRounds>=1 && o.jointPairsPerTrigger>=1 && ...
    o.jointMaxCombinations>=1 && o.originalSearchRounds>=1);
assert(o.seed<=2^32-1);
positive = [o.maxSeconds,o.fairnessStep,o.throughputStep,o.sbTimeStep,o.sbCoupling];
assert(all(isfinite(positive)) && all(positive>0));
assert(isfinite(o.penaltyFactor) && o.penaltyFactor>1);
assert(isfinite(o.fairnessBudgetFraction) && o.fairnessBudgetFraction>0 && o.fairnessBudgetFraction<1);
assert(isfinite(o.stepExponent) && o.stepExponent>0.5 && o.stepExponent<=1);
assert(isfinite(o.gapTolerance) && o.gapTolerance>=0);
assert(isfinite(o.crossResourceFraction) && o.crossResourceFraction>=0 && o.crossResourceFraction<=1);
if exist('stopping','var'), o.stopping=stopping; end
if exist('audit','var'), o.audit=audit; end
if exist('fastPolish','var'), o.fastPolish=logical(fastPolish); end
if exist('iterationFields','var')
    names=fieldnames(iterationFields);
    for j=1:numel(names), o.(names{j})=iterationFields.(names{j}); end
end
end
