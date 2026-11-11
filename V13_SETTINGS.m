function [options,resultFolder] = V13_SETTINGS()
%V13_SETTINGS 编辑这里即可调整停止阈值；改协议时使用新的结果子目录。
options.budgetSeconds=120;            % 每方法最长预算，包含共同建模；允许提前结束
options.method.stopping=struct( ...
    'enabled',true, ...                 % false：关闭新提前停止，恢复预算/原迭代限制
    'relativeGap',.01, ...              % 原模型有效上界相对差距<=1%：已认证近优
    'minPhaseSeconds',10, ...           % 停滞判断前，每阶段至少搜索10秒
    'patienceSeconds',20, ...           % 连续20秒没有明显改善：停滞停止
    'relativeImprovement',1e-4, ...      % 相对改善0.01%才重置停滞时钟（累计计算）
    'minIterations',3);                 % 停滞判断前至少3次本方法外层迭代
resultFolder='v13_from_v12_64users_16streams_adaptive';
end
