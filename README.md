# LEO QoS V6：固定种子与折线对比

[下载 V6 纯源码包](LEO_QoS_Comparison_v6.zip)。独立分支 `leo-qos-v6-reproducible-lines`，旧版保留在原分支。本版ZIP不含验证结果、示例图、MAT数据或旧压缩包。

默认32用户、8×8=64阵元、32码本波束、8射频链、**每块最多8人**；20个50 ms块、1秒周期、20 MHz、每流10 W、80 W功率预算、每用户1 Mbit需求、95%联合可靠性。基础种子固定 **71669974**。物理参考参数为600 km、4 GHz、Rician 12 dB和6/1 dB天线增益；论文与本模型的区别见 PAPER_REFERENCE.md。

## MATLAB运行

解压到新目录，例如 `D:\code\LEO_QoS_Comparison_v6`。在命令窗口运行：

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v6')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
[report,fig] = run_leo_comparison();
```

也可直接打开根目录 `RUN_COMPARISON.m` 并点击运行。默认14项基础MATLAB方法/消融，不使用外部优化求解器。每方法12秒端到端软预算；一些方法可能提前停止或略超时，耗时按实际记录。1000个独立衰落周期用于固定日程后的验证。

结果保存在 `results/comparison/seed_71669974`；重复运行增加 `_run_2` 后缀，不覆盖已有结果。`run_seed.csv`首先记录本次种子，`raw_benchmark.mat`保存算法原始结果。图形失败时可运行 `RECOVER_COMPARISON.m` 选择备份恢复。

## 本次修改

- L恢复8，默认固定种子71669974；只有显式传入`randomSeed=true`才自动抽新种子。
- 修正离线码本数值并列的选择方式，导出码本、固定用户和候选域用于跨MATLAB/Octave核对。见 [REPRODUCIBILITY.md](REPRODUCIBILITY.md)。
- 综合对比、QoS、理论界、恢复图和详细图中的原柱状图全部改为带标记的折线；调度矩阵等仍用热图。方法轴是离散类别，连接线不代表类别之间存在连续插值。缺失/未达标结果留空。
- 上界新增逐块枚举数量与逐轮对偶界CSV，计算过程与局限见 [THEORETICAL_BOUND.md](THEORETICAL_BOUND.md)。

固定种子不会使SB必然优于禁忌，也不能消除运行速度和浮点实现差异。本版没有为获得某个排名而改变需求、可靠性目标或搜索结果。

## 目标与指标

所有用户的充分保证条件G_i>=q_i满足后，才最大化保证总服务；否则报告`full_qos_not_found`，只保留诊断日程，不参与正式吞吐与界差排名。目标与多级衰落证书推导见 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md)。`completed`只表示程序完成，不代表QoS达标或全局最优。

`method_comparison.png`比较证书公平、达标率、全员达标后的保证速率、衰落平均速率和实际耗时；`additional_qos_metrics.png`给出Jain等额外指标；`theoretical_bound.png`显示统一门槛下的有效上界与最优差距范围；另外输出18张诊断图。方法定义见 METHODS_AND_METRICS.md。

数学证书与物理平均吞吐是不同量，上界针对固定的确定性保证服务模型，不能当作实际平均吞吐的上界。所有测试与数值检查在Octave完成，Python图形规格渲染用于检查折线；MATLAB桌面图形仍需用户实际环境验证。
