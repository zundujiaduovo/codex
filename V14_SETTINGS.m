function [o,folder]=V14_SETTINGS()
% 物理模型与128阵元V13一致；所有搜索按有限迭代/工作量上限运行。
[o,~]=V13_SETTINGS('combined');
o.method.coordination=leo_v14_coordination_options();
o.method.refinement.poolSize=12; o.method.referenceMode='current_schedule';
o.method.fairnessRounds=120; o.method.throughputRounds=60;
o.method.fairnessStep=1; o.method.throughputStep=.15;
folder='v14_from_v13_fairness_coordination_stage2_v2';
end
