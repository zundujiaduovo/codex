function report = leo_check_problem_point(stage,z,tolerance)
%LEO_CHECK_PROBLEM_POINT 对完整变量向量检查上下界、整数、线性和 QoS。
% 接口标注：
% 输入：stage：问题模板；z：候选向量；tolerance：检查容差。
% 输出：report：边界、整数、线性及 QoS 约束的违反量/可行性。
if nargin<3, tolerance = 1e-9; end
assert(isvector(z) && numel(z)==numel(stage.lb) && all(isfinite(z(:))));
z = double(z(:));
report.boundViolation = max([0;stage.lb-z;z-stage.ub]);
report.integerViolation = max([0;abs(z(stage.intcon)-round(z(stage.intcon)))]);
report.linearViolation = max([0;stage.A*z-stage.b;abs(stage.Aeq*z-stage.beq)]);
if report.boundViolation>0
    % 服务回调只定义在 [0,1]；不把越界点投影后假装可行。
    report.nonlinearViolation = Inf;
else
    [c,ceq] = stage.nonlcon(z);
    report.nonlinearViolation = max([0;c(:);abs(ceq(:))]);
end
report.feasible = max([report.boundViolation,report.integerViolation, ...
    report.linearViolation,report.nonlinearViolation])<=tolerance;
end
