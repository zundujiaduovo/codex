# 迭代次数与完整对比图组

8 用户/3 块和 32 用户/20 块各重跑三个算法种子，每个规模输出 **18 张多子图**。
物理设置仍为固定 32 个码本波束、最多并发 8 人、每块 50 ms。
本轮结果另存 `results/plots_small` 和 `results/plots_default`，保留之前的实验。
图表采用英文坐标便于跨平台显示；函数和本说明采用中文。

## MATLAB 一键运行与重画

```matlab
addpath('matlab');
small = run_leo_benchmarks('small');     % 自动运行、导出数据及 18 张图
large = run_leo_benchmarks('default');

% 从本包已有结果重画，不必再次求解
run_leo_plot_results('results/plots_default/plot_data.mat','results/redraw_default');
run_leo_plot_results('results/plots_small/benchmark.mat','results/redraw_small');
leo_plot_benchmark(small,'results/redraw_from_report');

% 无图形后端也可导出全部绘图数值
run_leo_plot_results(small,'results/plot_numbers',false);
test_leo_plots();
```

MATLAB 渲染器输出 PNG、矢量 PDF 和可编辑 FIG。图形导出失败时，实验主函数仍保留
CSV、`benchmark.mat`、`plot_data.mat` 和 `plot_specs.json`，并记录 `plotStatus`。
`makePlots=false` 关闭渲染，但仍保存全部重画输入；绘图后处理时间不计入算法耗时。

云环境只有 Octave CLI、没有图形后端。本次算法、统计和图形数据全部由 `.m` 函数计算，
随包 PNG/PDF 由 Matplotlib 渲染同一份 MATLAB 导出的规格，没有另算一套实验结果：

```bash
python tools/render_plot_specs.py results/plots_small/plot_specs.json
python tools/render_plot_specs.py results/plots_default/plot_specs.json
```

每个结果目录含 `overview.png`、逐张 PNG/PDF、18 页 `all_figures.pdf` 和 `INDEX.md`。
轻量图表与 CSV 副本见 [小规模图表](examples/plots_small/INDEX.md) 和
[默认规模图表](examples/plots_default/INDEX.md)。完整 MAT、JSON、代码及图表在配套 ZIP 中。

## 图表目录

| 编号 / 文件前缀 | 内容及读法 |
|---|---|
| 01_performance | 原始封顶公平、净总服务 Mbit、完整 QoS 达标率、未封顶最差需求比 |
| 02_runtime | 实际端到端成本、预处理/搜索成本、软预算超额、代理刷新次数 |
| 03_iterations | 两阶段价格轮数、完整/部分轮数、贪心添加次数、交换/禁忌轮数、MILP 节点及调用次数 |
| 04_search_work | SB 积分步、轨迹步、资源子问题数、实际被修复候选数、恢复及原目标评价次数 |
| 05_price_convergence | 原始公平与总服务随价格轮次变化，两阶段分开；第 0 点为实际阶段起点 |
| 06_time_convergence | 各方法原始公平/总服务随实际核算时间变化；只使用真实记录点 |
| 07_optimality_gaps | 原问题有效界差、完整穷举差距；吞吐差距仅对各自固定公平门槛成立 |
| 08_bound_convergence | 原始可行值与有效上界，以及界差随价格轮次变化 |
| 09_price_feedback | Price+SB 两阶段逐用户价格、下界服务/需求比热图；负下界保持原值 |
| 10_user_service | 用户需求比热图、经验 CDF、Price+SB 服务与需求、各阶段逐用户服务 |
| 11_schedules | 所有已完成方法的二元调度矩阵；横轴为固定时间块 |
| 12_resources_and_sinr | 每块同时用户数、每块净服务、32 波束使用、活跃设计 SINR 的经验 CDF |
| 13_seed_variation | 三个种子的公平/吞吐/耗时原始点及时间—质量散点 |
| 14_sb_energy | 每阶段第一次固定 Ising 调用的最好、轨迹中位、最差历史最好能量 |
| 15_tangent_chord | 原始速率/切线/弦线、区间误差、固定 minimax 服务夹逼及用户误差上限 |
| 16_reference_ablation | 自适应、零切点、固定 minimax、固定当前切点及参考点组合的成绩/耗时/SB 工作量 |
| 17_status_and_availability | 执行状态及优化前物理可服务矩阵；completed 只表示返回可行解 |
| 18_phase_results | 共同初始化、公平阶段、吞吐阶段的原始成绩；组合方法展示获胜分支两阶段结果 |

## 迭代计数的单位

不同算法的一次迭代工作量不同，因此分别作图，不能直接用次数排名判断谁更快。

| 数据列 | 定义 |
|---|---|
| priceRounds1/2 | 已进入并记录反馈的价格轮数，包括时间耗尽时的最后一个部分轮次 |
| completeRounds1/2 | 本轮全部 M 个资源子问题均已返回，不表示每个内层都达到步数上限或求得最优 |
| searchSteps1/2 | 贪心为被接受的添加次数；交换和禁忌为检查过的邻域轮数 |
| sbIntegrationSteps | 所有实际 SB 调用的积分循环步数之和，不乘轨迹数 |
| sbTrajectorySteps | 积分步数乘每次调用的并行轨迹数；仍不是浮点运算量 |
| nodes1/2 | MILP 后端实际报告的分支定界节点数；本次 GLPK 不报告，因此为 NaN |
| milpCalls | 实际进入 MILP 后端的调用次数，不冒充节点数 |
| resourceSolves | 价格阶段实际返回的资源子问题调用数 |
| repairedCandidates | 用户位因硬约束修复发生改变的候选数 |
| recoveryEvaluations / crossEvaluations | 原式恢复的评价次数；跨块评价是总恢复评价的子集，不能二者相加 |
| originalEvaluations | 原目标基线搜索阶段累计候选评价数，不包括共同初始化 |
| portfolioMembers | 实际执行的参考点分支数；工作量累计所有分支，不只统计胜出分支 |

第 0 个收敛点不计为一次迭代。旧 MAT 缺少的历史/计数保持缺失，不由最终日程反推。
组合搜索只在分支完成时记录整个组合的已知最好成绩，各分支价格轨迹独立保存。
SB 能量图是修复前同一固定 Ising 问题的轨迹历史最优值，不是全周期 QoS 目标。
阶段或价格变化后 Ising 目标也改变，不同调用的绝对能量不可连成一条收敛曲线。

## 统计与模型口径

柱为三个算法种子的中位数，误差棒为最小—最大范围，**不是置信区间**。
代表性的收敛、日程、每用户诊断固定取第一个请求的种子 20261105，不挑选最好的一次。
三个种子共享同一个物理样本；未执行的用户数/需求/预算扫描不生成趋势或外推图。
零达标率如实绘制为零；缺失求解器、不可比的精确吞吐差距等显示 N/A，不填成零。

第 12 图是统计 CSI 低分位系数下的 **设计 SINR**，只统计实际活跃且有数据时间的样本，
不是瞬时随机衰落 SINR，也不是平均 SINR。第 15 图用同一固定 minimax 代理诊断各最终日程，
不混用各算法不同的最终自适应切点。速率示例固定取首个非零合法干扰区间。

## 本轮结果与迭代观察

GNU Octave 9.4.0，OpenBLAS 单线程；每方法软预算 12 s，算法种子 20261105/06/07。
每规模 33 次完成、3 次因 Gurobi 缺失而不可用，没有运行失败；全部完成日程通过原始硬约束和阶段 2 门槛验收。

| 规模 / 方法 | 公平中位数 | 总服务中位数 Mbit | 时间中位数 s | 价格轮数（公平/吞吐） |
|---|---:|---:|---:|---|
| 8 用户 Price+SB | 0.502761118 | 4.530960 | 6.801 | 24 / 12，均完整 |
| 8 用户原目标交换 | 0.502761118 | 4.530960 | 0.646 | 不适用；邻域轮数 4 / 3 |
| 8 用户直接代理 MILP | 0.502761118 | 4.530960 | 0.334 | 不适用；调用 2 次，节点数未报告 |
| 32 用户 Price+SB | 0.202486683 | 8.554573 | 12.200 | 2 / 1，其中完整轮数 1 / 0 |
| 32 用户 Price+Local | 0.202486683 | 8.554573 | 12.203 | 2 / 1，其中完整轮数 2 / 0 |
| 32 用户原目标禁忌 | 0.205099367 | 8.833922 | 12.160 | 不适用；邻域轮数中位数 35 / 17 |

小规模 SB 三次均达到完整穷举的原始字典序最优，较便宜的交换和代理 MILP 也达到相同结果。
大规模 SB 在短预算内只完成少量外层轮次，曲线平坦不等于已证明最优；当前结果仍未展示相对禁忌搜索的优势。
两种规模完整 QoS 达标率均为 0；提高最差需求满足比例不能解释为所有用户需求已满足。
日志开销包含在本轮计时内，时间停止点会影响结果；上一轮保留在 BENCHMARK_RESULTS.md，不混用两轮耗时。

## 函数与数据接口

| 函数 | 职责 |
|---|---|
| leo_record_search_step | 原目标基线记录真实搜索步、可行成绩和累计评价次数 |
| leo_ballistic_sb | 每个检查点保留固定 Ising 调用的离散历史最好能量统计 |
| leo_run_price_phase | 价格轮数、完整标记、资源/SB/恢复工作量、阶段起点及首次 SB 能量轨迹 |
| leo_run_benchmark_method | 组合参考点搜索记录所有成员工作量及真实时间偏移 |
| leo_collect_plot_data | 合并计数/轨迹，生成代表日程与固定代理诊断，不运行优化 |
| leo_build_plot_specs | 分图组织、种子统计、单位换算和缺失值，形成唯一绘图规格 |
| leo_export_plot_data | CSV/MAT/JSON 导出，支持没有图形后端的环境 |
| leo_render_plot_specs | 基础 MATLAB 绘图及 PNG/PDF/FIG 导出 |
| leo_plot_benchmark | 报告到完整图组的兼容入口 |
| run_leo_plot_results | 从已有 MAT/报告重画，不重跑算法 |
| test_leo_plots | 计数/成员/时间/Dref/能量/兼容/缺失值/导出的 9 组检查 |

`iterations.csv` 是每方法/种子的计数；`iteration_history.csv` 是分支/阶段成绩和有效上界；
`convergence.csv` 是可用时刻的保存成绩；`price_history.csv` 是用户价格及下界需求比；
`sb_energy.csv` 是各阶段首个内层调用的能量轨迹。单位写在列名或本说明中。
`plot_data.mat` 是 MATLAB 重画输入；`plot_specs.json` 是两个渲染器共用的数值规格。
完整输入输出和调用关系见 [FUNCTION_GUIDE.md](FUNCTION_GUIDE.md)。
