# LEO QoS V5：先全员 QoS，再比较总服务

[下载完整 V5 运行包](LEO_QoS_Comparison_v5.zip)。独立分支 `leo-qos-v5-full-qos`；旧版本保留在原分支，本分支只放 V5 压缩包。

本次先修改数学逻辑，再同步代码：目标是所有用户满足周期 QoS 的联合概率至少 95%，以充分的保证服务条件 G_i>=q_i 求解；找到全员达标日程后才最大化保证总服务。搜索未找到全员达标日程时明确显示 `full_qos_not_found`，只保留诊断结果，不参与正式吞吐/最优差距排名。这不证明原随机系统不可行。

新多级衰落下界保留原先被当作零的低衰落槽服务，参数在共同确定性校准日程上选择并冻结，所有算法使用同一个证书。不增加功率，不降低业务需求，不放松可靠性。完整推导、目标与假设见 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md)。新旧证书最优值不同，不能直接把保证服务数值提升当作物理容量或 SB 算法提升。

## 当前配置

32 用户、固定 `reference32` 坐标、8×8=64 天线阵元、32 个固定码本波束、8 条射频链、**每块最多 7 人**（严格“小于 8”）；20 个 50 ms 块，总周期 1 秒。每流 10 W，总功率预算 80 W，7 流最多用 70 W；20 MHz，每用户需求 1 Mbit/周期，联合风险 5%。参考论文的部分参数为 600 km、4 GHz、Rician 12 dB、天线增益 6/1 dB。论文与当前下行模型的区别见 [PAPER_REFERENCE.md](PAPER_REFERENCE.md)。

主入口参数来自 `matlab/leo_paper_parameters.m`。历史 `leo_default_parameters()`、单独旧示例仍保留 V3/V4 基线语义，不能把它们的结果冒充当前 V5 主实验。

## MATLAB 运行

解压到新目录，避免与旧版本路径混用。假设目录为 `D:\code\LEO_QoS_Comparison_v5`：

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v5')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
[report,fig] = run_leo_comparison();
```

也可直接打开根目录 `RUN_COMPARISON.m` 并点击运行。默认比较 **14 项基础 MATLAB 方法/消融**，每方法 12 秒端到端软预算，所有方法共享一个自动生成并记录的随机种子。外部 MIQP/MILP 默认不参与，代码仍保留可选接口。不同方法可能提前停止或略超时，按实际记录评估。

每次写入独立目录 `results/comparison/seed_<种子>`；同种子再次运行会增加目录后缀，不覆盖结果。`run_seed.csv` 先写入；算法结束先保存 `raw_benchmark.mat`，然后汇总、1000 周期独立衰落验证、理论界和绘图。若绘图中断，可运行 `RECOVER_COMPARISON.m` 选择保存目录重画，无需再次优化。

复查本次固定种子，或使用更长预算：

```matlab
o = struct('seeds',71669974,'budgetSeconds',60);
[report,fig] = run_leo_comparison(fullfile(pwd,'results','comparison'),o);
```

这只是复查示例；默认种子不使用日期。相同种子不能消除 MATLAB/Octave 浮点差异、码本并列选择或软时间预算带来的结果差异。

## 结果怎么读

- `goalStatus=full_qos_met`：日程通过 G_i>=q_i 的全员条件，可以比较保证总服务和有效上界。
- `goalStatus=full_qos_not_found`：搜索返回诊断日程，未找到目标可行解；不证明原机会约束问题不可行。
- `status=completed`：程序完成返回，不等于达到 QoS 目标，更不等于全局最优。
- `fairness`：最差保证完成比例，在 1 封顶；`qosSatisfactionRate`：证书达标用户比例。
- `feasibleTotalBits`：仅达标日程填写的保证总服务；`totalBits` 保留所有诊断日程的服务量。
- `sampleJointSuccessRate`：固定日程后独立衰落样本的全员达标频率；不是精确概率。另给单侧 95% 失败概率上限。

主图 `method_comparison.png` 的保证总速率栏只比较达标日程；未达标标为缺失。`theoretical_bound.png` 的上界针对统一 G_i>=q_i 问题；不能当作物理容量或必然可达最优。`additional_qos_metrics.png` 和 18 张诊断图分别提供 Jain 公平、样本 QoS、时间、迭代、日程等。

`certificate_parameters.csv` 保存冻结的每用户证书参数；`same_schedule_certificates.csv` 在完全相同的日程上比较新旧保证公式，用于区分数学下界变紧与算法改进。

方法和字段见 [METHODS_AND_METRICS.md](METHODS_AND_METRICS.md)，SB 变体见 [ADAPTIVE_SB.md](ADAPTIVE_SB.md)，上界见 [THEORETICAL_BOUND.md](THEORETICAL_BOUND.md)。本次验证结果见 [V5 报告](results/v5_evaluation/REPORT.md)。

## 验证与依赖

基础方法、概率计算、上界不需要外部优化工具箱。可选 `proxy_milp` 需要 intlinprog/GLPK，`price_miqp` 需要 Gurobi。新公式通过独立有限衰落枚举、所有小规模合法日程、代理/上界及未达标阶段门控检查：`test_leo_v5()`。历史方法、周期证书、绘图数据及理论上界回归仍保留。

本构建环境使用 Octave CLI。MATLAB 桌面图形未实机验证；数值图形规格可用 `tools/render_plot_specs.py` 重画。真实信道若存在显著槽间相关性，需要重新建模，当前独立槽证明不能直接外推。
