function [options,resultFolder] = V13_SETTINGS(profile)
%V13_SETTINGS 128阵元版：按最大迭代次数运行，不按时间/停滞/近优差距停止。
% baseline / iterations / refresh / candidates / combined，分别开关三项改进。
if nargin<1, profile='combined'; end
assert(any(strcmp(profile,{'baseline','iterations','refresh','candidates','combined'})));
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
options.method.refinement=struct('candidatePool',false,'bottleneckCandidates',false,'candidateRefresh',false, ...
    'poolSize',8,'bottleneckBand',.03,'gapTrigger',.01);
if any(strcmp(profile,{'iterations','combined'}))
    options.method.fairnessRounds=120; options.method.throughputRounds=60;
end
if any(strcmp(profile,{'refresh','combined'}))
    options.method.refreshEvery=1; options.method.refinement.candidateRefresh=true;
end
if any(strcmp(profile,{'candidates','combined'}))
    options.method.refinement.candidatePool=true; options.method.refinement.bottleneckCandidates=true;
end
resultFolder=['v13_proxy_refinement_',profile];
end
