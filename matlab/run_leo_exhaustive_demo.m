function [model,comparison] = run_leo_exhaustive_demo(p)
%RUN_LEO_EXHAUSTIVE_DEMO 可实际完成的穷举对照：8 用户，3 个 50 ms 资源。
% 接口标注：
% 输入：p：可选自定义参数；省略时 8 用户/3 块。
% 输出：model/comparison：原始完整穷举及轮换/预检见证对比。
% 保持 32 码本波束、最大 8 并发与原始设计速率。传入 p 时不改其规模。
if nargin<1
    p = leo_default_parameters();
    p.system.K = 8;
    p.time.nSlots = 15;
end
if ~isfield(p,'exhaustive'), p.exhaustive = leo_exhaustive_options(); end
p.exhaustive.enabled = true;
model = run_leo_sinr(p);
schedules = {model.xExample,model.problem.precheck.witness};
names = {'Rotating example','Feasibility witness'};
if model.exhaustive.hasIncumbent
    schedules{end+1} = model.exhaustive.x;
    if model.exhaustive.completed
        names{end+1} = 'Exhaustive lexicographic optimum';
    else
        names{end+1} = 'Exhaustive incumbent (incomplete)';
    end
end
comparison = leo_compare_schedules(model.problem,schedules,names);
fprintf('\nComparison on the same design-service model:\n');
for k = 1:numel(comparison)
    fprintf('%-34s fairness=%.9g  total=%.9g Mbit\n',comparison(k).name, ...
        comparison(k).fairness,comparison(k).totalBits/1e6);
end
end
