function [options,resultFolder] = V13_SETTINGS()
%V13_SETTINGS 128阵元版：按最大迭代次数运行，不按时间/停滞/近优差距停止。
options.method.iterationOnly=true;
options.method.fairnessRounds=60;
options.method.throughputRounds=30;
options.method.originalFairnessRounds=2000;
options.method.originalThroughputRounds=1000;
options.method.sbSteps=500;
options.method.sbTrajectories=32;
options.method.localRestarts=32;       % 配对Local同时增加起点数
options.method.polishMoves=12;
options.method.refreshEvery=2;
options.method.fastPolish=true;       % 同一局部动作及平局顺序的向量实现，SB/Local共用
options.method.proxyTabuIterations=80; % 每次固定二次块目标、每个起点的Tabu轮数
options.method.proxyTabuRestarts=4;    % 旧组、空组和两个随机修复起点
options.method.proxyTabuTenure=7;
options.method.audit=struct('enabled',true,'snapshots',4,'tabuMoves',16);
options.method.stopping=struct('enabled',false);
% 理论证书也不设时间截断，保留列生成迭代/节点等有限上限。
options.fairnessCertificateOptions=struct('maxSeconds',Inf,'relaxationMaxSeconds',Inf, ...
    'relaxationMaxIterations',300,'maxNodes',128,'maxIterations',150,'recoverySeconds',0);
options.throughputCertificateOptions=struct('maxSeconds',Inf,'maxNodes',128,'maxIterations',150,'recoverySeconds',0);
resultFolder='v13_64users_128ant_iterations';
end
