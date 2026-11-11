function [options,resultFolder] = V13_SETTINGS()
%V13_SETTINGS 编辑这里即可调整停止阈值；改协议时使用新的结果子目录。
options.budgetSeconds=120;            % 每方法最长预算，包含共同建模；允许提前结束
options.method.sbSteps=500;
options.method.sbTrajectories=32;
options.method.localRestarts=32;       % 配对Local同时增加起点数
options.method.polishMoves=12;
options.method.refreshEvery=2;
options.method.fastPolish=true;       % 同一局部动作及平局顺序的向量实现，SB/Local共用
options.method.audit=struct('enabled',true,'snapshots',4,'tabuMoves',16);
options.method.stopping=struct( ...
    'enabled',true, ...                 % false：关闭新提前停止，恢复预算/原迭代限制
    'relativeGap',.01, ...              % 原模型有效上界相对差距<=1%：已认证近优
    'minPhaseSeconds',10, ...           % 停滞判断前，每阶段至少搜索10秒
    'patienceSeconds',40, ...           % 给更重的内层更多外层探索机会
    'relativeImprovement',1e-4, ...      % 相对改善0.01%才重置停滞时钟（累计计算）
    'minIterations',6);
resultFolder='v13_64users_scaled_audit';
end
