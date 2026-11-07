function result = leo_evaluate_service_bounds(problem,proxy,x)
%LEO_EVALUATE_SERVICE_BOUNDS 对同一合法完整日程比较下界、原始服务、上界。
% 接口标注：
% 输入：problem/proxy：原模型与同一模型代理；x：合法日程。
% 输出：result：下界、原始、上界服务及夹逼检查。
% 周期模式 gap 比较未截断的 A-margin；风险余量相消，误差预算仍有效。
data = problem.data;
result.original = problem.evaluate(x);
result.lower = leo_evaluate_quadratic_service(data,proxy.lower,x,false);
result.upper = leo_evaluate_quadratic_service(data,proxy.upper,x,false);
result.lowerGapBits = result.original.signedUserBits-result.lower.userBits;
result.upperGapBits = result.upper.userBits-result.original.signedUserBits;
result.lowerErrorBudgetBits = sum(proxy.error.lowerResourceBits.*x,2);
result.upperErrorBudgetBits = sum(proxy.error.upperResourceBits.*x,2);
tol = 1e-10*max(1,abs(result.original.signedUserBits));
result.sandwichValid = all(result.lowerGapBits>=-tol) && all(result.upperGapBits>=-tol);
result.errorBudgetsValid = all(result.lowerGapBits<=result.lowerErrorBudgetBits+tol) && ...
    all(result.upperGapBits<=result.upperErrorBudgetBits+tol);
assert(result.sandwichValid && result.errorBudgetsValid,'服务上下界或误差预算检查失败。');
end
