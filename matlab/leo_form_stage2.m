function stage = leo_form_stage2(data,x0)
%LEO_FORM_STAGE2 O4：用给定可行日程的实际设计公平值形成第二阶段。
% 接口标注：
% 输入：data：原问题数据；x0：K×M 已有合法日程。
% 输出：stage：以 x0 原始公平为固定门槛的 O4 模板。
% 不把输入日程当成第一阶段最优解，不进行优化求解。
reference = leo_evaluate_service(data,x0);
s0 = reference.fairness;
if leo_requires_full_qos(data), s0=1; end
stage.name = 'P_V(s0): maximize normalized design throughput';
stage.objective = @(z) leo_problem_objective(z,data,2);
stage.nonlcon = @(z) leo_problem_nonlcon(z,data,2,s0);
stage.A = data.hard.A; stage.b = data.hard.rhs;
stage.Aeq = sparse(0,prod(data.shape)); stage.beq = [];
stage.lb = data.hard.lower; stage.ub = data.hard.upper;
stage.intcon = data.hard.integerIndices;
stage.x0 = double(x0(:));
stage.s0 = s0;
stage.fairnessFloorSource = 'Actual design fairness of supplied feasible schedule; not a proven optimum.';
stage.initialMeetsFloor=all(reference.demandRatio>=s0);
if leo_requires_full_qos(data), stage.fairnessFloorSource='Required common full-user QoS floor 1; initial point may be infeasible.'; end
stage.sense = 'minimize';
stage.solved = false;
end
