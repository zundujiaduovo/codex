function [model,comparison] = run_leo_surrogate_demo()
%RUN_LEO_SURROGATE_DEMO 在原 8 用户/3 块穷举小例上验证切线与弦线。
% 接口标注：
% 输入：无；使用固定 8 用户/3 块穷举例。
% 输出：model/comparison：minimax 与当前点相切的服务夹逼/误差验证。
p = leo_default_parameters(); p.system.K = 8; p.time.nSlots = 15;
p.exhaustive.enabled = true;
model = run_leo_sinr(p);
assert(model.exhaustive.completed,'本对照需要原始问题完整穷举已完成。');
x = model.exhaustive.x;
comparison.minimax = leo_evaluate_service_bounds(model.problem,model.surrogate,x);
comparison.allMinimaxGroups = leo_check_surrogate_groups(model.problem,model.surrogate);
comparison.touchingProxy = leo_build_service_surrogates(model.problem,'current_schedule',x);
comparison.touching = leo_evaluate_service_bounds(model.problem,comparison.touchingProxy,x);
comparison.allTouchingGroups = leo_check_surrogate_groups(model.problem,comparison.touchingProxy);
fprintf('At original exhaustive optimum, total [lower, original, upper] in Mbit:\n');
fprintf('minimax : [%.12g, %.12g, %.12g]\n',comparison.minimax.lower.totalBits/1e6, ...
    comparison.minimax.original.totalBits/1e6,comparison.minimax.upper.totalBits/1e6);
fprintf('touching: [%.12g, %.12g, %.12g]\n',comparison.touching.lower.totalBits/1e6, ...
    comparison.touching.original.totalBits/1e6,comparison.touching.upper.totalBits/1e6);
fprintf('Checked all %d per-resource groups for each construction; no SB run.\n', ...
    comparison.allMinimaxGroups.groupsChecked);
end
