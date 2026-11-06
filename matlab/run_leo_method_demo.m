function [model,comparison] = run_leo_method_demo(p)
%RUN_LEO_METHOD_DEMO 默认 8 用户/3 个固定块，与原问题完整穷举对照。
% 接口标注：
% 输入：p：可选自定义参数；省略时 8 用户/3 块并启用穷举。
% 输出：model/comparison：两阶段方法、后置穷举及同原始服务口径的比较。
% 仍为 32 波束、最多并发 8 人；用户传入 p 时绝不自动缩小规模。
if nargin<1
    p = leo_default_parameters();
    p.system.K = 8; p.time.nSlots = 15;
    p.exhaustive.enabled = true;
end
p.method.enabled = true;
model = run_leo_sinr(p);             % 方法先运行，穷举仅在其后用作对照
schedules = {model.xExample,model.method.initial.x,model.method.stage1.x,model.method.x};
names = {'cyclic_example','method_initial','method_stage1','method_final'};
if isfield(model,'exhaustive') && model.exhaustive.optimal
    schedules{end+1} = model.exhaustive.x; names{end+1} = 'exhaustive_optimum';
end
comparison = leo_compare_schedules(model.problem,schedules,names);
for j = 1:numel(comparison)
    fprintf('%-20s fairness=%.12g, throughput=%.9g Mbit\n', ...
        comparison(j).name,comparison(j).fairness,comparison(j).totalBits/1e6);
end
if isfield(model,'exhaustive') && model.exhaustive.optimal
    model.method.exhaustiveFairnessGap = model.exhaustive.fairness-model.method.service.fairness;
    fprintf('Exact reference fairness gap: %.12g\n',model.method.exhaustiveFairnessGap);
end
end
