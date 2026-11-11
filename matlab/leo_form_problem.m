function problem = leo_form_problem(p,r,b,design)
%LEO_FORM_PROBLEM 第 6 节 O1-O4：形成原始非线性混合整数问题，不求解。
% 接口标注：
% 输入：p/r/b/design：参数、资源、波束、设计服务系数。
% 输出：problem：原始两阶段问题回调、数据与可服务性预检；尚未求解。
% 不进行切线、拉格朗日、QUBO、SB；不加入第 20 节可选吞吐底线。
hard = leo_build_hard_constraints(p,r,b);
data.shape = [p.system.K,r.nResources];
data.hard = hard;
data.available = b.available;
data.beamIndex = b.index;
data.maxStreams = p.system.maxStreams;
data.slotToResource = r.slotToResource;
data.dataDurationS = r.dataDurationS;
data.bandwidthHz = p.system.bandwidthHz;
data.qosTargetBits = p.system.qosTargetBits;
data.referenceBits = p.problem.referenceBits;
data.periodSeconds = p.time.nSlots*p.time.slotDurationS;
data.design = design;
data.requireFullQos = isfield(p.problem,'requireFullQos') && p.problem.requireFullQos;
if isfield(p.problem,'objectiveMode'), data.objectiveMode=p.problem.objectiveMode; end
if leo_is_lexicographic(data), data.fairnessUpperLimit=leo_fairness_limit(data); end
n = prod(data.shape);
stage.name = 'P_F: maximize capped minimum normalized design service';
if leo_is_lexicographic(data), stage.name='P_F: maximize UNCAPPED minimum cumulative guaranteed-service ratio'; end
stage.objective = @(z) leo_problem_objective(z,data,1);
stage.nonlcon = @(z) leo_problem_nonlcon(z,data,1,0);
stage.A = [hard.A,sparse(size(hard.A,1),1)]; stage.b = hard.rhs;
stage.Aeq = sparse(0,n+1); stage.beq = [];
stage.lb = [hard.lower;0]; stage.ub = [hard.upper;leo_fairness_limit(data)];
stage.intcon = hard.integerIndices;  % 最后 s 是连续变量，不在 intcon 中
stage.x0 = zeros(n+1,1);            % O2 的空日程、s=0 是已知可行点
stage.sIndex = n+1;
stage.sense = 'minimize';            % objective 返回 -s
stage.solved = false;
problem.kind = 'Original nonlinear mixed-integer model, sections 5-6';
problem.solved = false;
problem.data = data;
problem.hard = hard;
problem.stage1 = stage;
problem.evaluate = @(x) leo_evaluate_service(data,x);
problem.makeStage2 = @(x0) leo_form_stage2(data,x0);
problem.precheck = leo_precheck_positive_fairness(data);
problem.feasibilityTolerance = p.problem.feasibilityTolerance;
end
