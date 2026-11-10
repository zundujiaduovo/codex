# LEO QoS V8：每种 SB 的收敛曲线

[下载 V8 纯源码包](LEO_QoS_Comparison_v8.zip)。分支leo-qos-v8-sb-convergence；仅含源码、测试代码与说明，不含验证结果、图像、MAT或旧ZIP。

V8增加每个SB方法/消融的独立收敛图，以及与禁忌、局部搜索的时间曲线对照。已有V7结果可以直接重画，不需重跑。新运行记录更细的原目标改进时刻。物理配置、算法搜索规则及V7证书求解器沿用原设置：32用户、8×8阵元、32波束、最多8人、固定种子71669974；默认14项方法，每方法12秒软预算。

## 只给已有V7结果加收敛图

解压V8到D:\code\LEO_QoS_Comparison_v8，在MATLAB命令窗口运行：

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v8')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
source='D:\code\LEO_QoS_Comparison_v7\results\comparison\seed_71669974\benchmark.mat';
run_leo_sb_convergence(source);
```

图保存在旧结果目录下sb_convergence。每种SB一张图，另有sb_convergence_comparison汇总比较。每张图含服务/时间、公平/时间、外层轮数和一个固定子问题的SB能量。详见 [SB_CONVERGENCE.md](SB_CONVERGENCE.md)。

## 重新运行完整比较

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v8')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
opts=struct('budgetSeconds',60);
[report,fig]=run_leo_comparison(fullfile(pwd,'results','comparison_60s'),opts);
```

可把60改为所需的统一时间预算。省略opts则默认12秒。完整运行自动保存原有图组和新增SB收敛图；实际停止原因、时间预算、轮数上限都按日志记录。新增曲线不改变验收和优化目标，日志开销计入实际耗时。

## 如何读收敛曲线

时间曲线比较同场景同预算的真实保存值，不延伸停止后的轨迹。初始化公平已经为1时，重点看保证总服务的变化。外层曲线属于SB+价格协调+修复的整个流程；内层能量只属于图中注明的一个固定Ising调用，不能拼接不同轮的能量。未执行阶段和缺失日志留空。公平阶段的总服务可能下降，图保留原值。

禁忌使用原目标的增删、替换和跨块交换，短期记忆改动位置并允许可行域内暂时退步；细节和参数见SB_CONVERGENCE.md。证书阶段的新日程与被测方法成绩分别保存，最优区间规则见CERTIFICATE_SEARCH.md。

上界计算仍可通过run_leo_theory_from_saved读取已有结果重算，源结果旁的certificate_v7目录沿用V7命名。模型、目标与复现说明见FULL_QOS_MODEL.md、THEORETICAL_BOUND.md、REPRODUCIBILITY.md。数值/日志及旧结果重画在Octave验证，图形规格以Python渲染检查；MATLAB桌面图形未实机运行。
