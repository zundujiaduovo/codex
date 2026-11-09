# 基础方案的统一对比实验

**V6 主入口更新：** 当前目标与多级证书以 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md) 为准；下文保留基础/历史推导与接口背景。主入口使用32用户、8×8阵列、32波束、每块最多8人，统一全员QoS门槛；旧入口的参数与降低门槛行为不能混作V6实验。

2026-11-07：默认采用 [周期累计 QoS 证书](PERIODIC_QOS.md)，旧 `slot_union` 可显式选择。服务总量/公平/QoS 均按当前证书口径；标称和衰落仿真吞吐单列，不混作保证。历史结果文件保持原样。

本入口对应方案第 13.3 节，在用户指定的固定时间块模型下比较。代码完整性边界见
[IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)，实测数值见 [BENCHMARK_RESULTS.md](https://github.com/zundujiaduovo/codex/blob/leo-qos-v5-full-qos/BENCHMARK_RESULTS.md)。

## 一键运行

```matlab
addpath('matlab');
small = run_leo_benchmarks('small');       % 8 用户、3 块；后置完整穷举
large = run_leo_benchmarks('default');     % 32 用户、20 块；穷举报告规模超限

% 用同一更长预算和记录的种子运行所有方法：
opts.budgetSeconds = 60;
opts.seeds = 429756090;   % 示例：替换为 run_seed.csv 中的实际基础种子
report = run_leo_benchmarks('default',opts);

% 自定义模型始终按给定规模运行：
p = leo_default_parameters();
p.system.K = 16;
report = run_leo_benchmarks(p,struct('budgetSeconds',30));
```

默认实验预算为每方法 **12 s**，默认固定算法种子71669974。
这是可快速复查的演示配置；正式统计实验需要更多物理样本、种子及预算档位。
同一 case 的物理样本由 `p.seed` 决定，各算法种子只改变初始化/搜索。一次随机种子结果不代表多种用户/信道环境的统计表现。

## 方法定义

| 实验名 | 内容 | 依赖 |
|---|---|---|
| initial | 所有方法共用的初始化择优结果 | 基础 MATLAB |
| original_greedy | 需求缺口优先，按原始服务选择可加块；和共同初始化择优 | 基础 MATLAB |
| original_exchange | 原始服务上的可行增删、替换、跨块交换 | 基础 MATLAB |
| original_tabu | 原目标邻域搜索，禁忌期限 5，优于保存结果时赦免 | 基础 MATLAB |
| price_sb | 基础两阶段价格+SB，每 6 轮当前点相切 | 基础 MATLAB |
| price_sb_blockwise | 原 SB 加逐块原目标验收 | 基础 MATLAB |
| price_sb_adaptive | 逐块验收，切点每轮刷新 | 基础 MATLAB |
| price_sb_light | adaptive 的轻量 SB：100 步、8 轨迹 | 基础 MATLAB |
| price_local | 同样代理、价格、修复与验收，内层换多起点局部搜索 | 基础 MATLAB |
| price_local_adaptive | 与 adaptive 相同验收和刷新，内层换局部搜索 | 基础 MATLAB |
| price_miqp | 同样价格，资源二元二次问题交给 Gurobi | Gurobi MATLAB 接口及有效许可 |
| proxy_milp | 完整周期代理直接线性化，两个阶段用 MILP 求解 | MATLAB intlinprog 或 Octave GLPK |
| sb_zero | 第一阶段固定零干扰切点 | 基础 MATLAB |
| sb_minimax_fixed | 第一阶段固定 minimax 切点 | 基础 MATLAB |
| sb_current_fixed | 第一阶段在共同初始最好日程处相切并固定 | 基础 MATLAB |
| sb_reference_portfolio | 以上三种参考点独立搜索，平分可用总预算，按原始目标择优 | 基础 MATLAB |

切点消融的第二阶段始终在其阶段 1 保留日程处相切，否则可能失去代理可行起点。
三参考点组合有独立初始化/构造成本，预算包含这些费用；它没有使用多层辅助位。
直接 MILP 为每个可能共选的用户对引入连续 y，并施加 `y<=xi, y<=xj, xi+xj-y<=1`。
x 为二元时 y 精确等于乘积。求得代理最优不表示原始速率最优；原始服务仍独立验收。

## 相同输入和计时

1. 所有方法共享位置、轨道、码本、候选域、固定功率、风险分配、净数据时间和需求。
2. 对每个种子，各方法按同样规则产生空日程、最大流见证、轮换、需求轮转及随机初始化。
3. 原目标搜索与日程恢复都用 `leo_resource_service`，仅重算受影响块的最多 L 位活跃用户，约 O(H_m L²)。
4. 共同物理/问题建模只执行一次；为端到端成本核算，其耗时分别计入每个方法。
   使用预建 minimax 代理的方法另计其构造耗时；自行构造代理的耗时在搜索计时内。
5. 每种方法的可用搜索时间为总预算减去上述预处理；初始化、代理、内层、修复、原式复核和上界均计时。
6. 依次运行各方法，不用多算法同时争用 CPU 的耗时排名。独立穷举最后运行并使用独立预算，属于证书对照。

`endToEndSeconds` 是上述单方法成本核算，不是整套共享预处理实验的墙钟时间。
算法可因轮数、局部停滞或有效界差而提前退出，不强制消耗完整预算。
软预算超额单列，出现明显超额时应按实际时间判断对比，不能宣称严格同秒数竞赛。

## 指标与文件

| 文件 / 字段 | 含义 |
|---|---|
| runs.csv | 每个方法/种子的状态、原始质量、上界、耗时及预算超额 |
| summary.csv | 成功/不可用/失败次数，中位公平、最好公平及该最好运行的吞吐、中位其他指标 |
| user_service.csv | 每用户目标 bit、实际设计服务 bit、D_i/q_i |
| schedules.csv | 每方法/种子的完整二元块日程及预指派码字 |
| benchmark.mat | 完整数值报告、原始模型数据、算法参数、日程和求解记录 |
| 01_performance 至 18_phase_results | 性能、迭代、收敛、界差、日程等完整图组，详见 PLOTS.md |
| iterations.csv / iteration_history.csv | 各口径迭代计数、阶段/分支迭代轨迹与原始有效界 |
| convergence.csv / price_history.csv / sb_energy.csv | 真实时间检查点、逐用户价格和固定 Ising 的能量轨迹 |
| plot_data.mat / plot_specs.json | 无需再次优化即可重画的数值数据及共享图形规格 |
| worstDemandRatio / fairness | 原始最差需求满足率 / 在 1 封顶后的公平目标 |
| qosSatisfactionRate | 原始 D_i>=q_i 的用户比例 |
| hardFeasible | 最终完整二元日程通过同一原始评价器的硬约束验证 |
| fairnessGap | 独立有效原始公平上界减可行值 |
| throughputGapBits | 各自固定 s0 下的有效原始吞吐界差 |
| exactFairnessGap | 小规模完整穷举最优公平减可行公平 |
| exactThroughputGapBits | 仅原始公平门槛相同且实际达标时报告，否则 NaN |
| solverStatus | 价格阶段停止状态，或 MILP 求解器原始状态码 |

`unavailable` 表示所需外部求解器不存在，`failed` 表示运行报错；二者不进入质量统计，也不填成零。
`completed` 只表示返回了经过复核的完整日程，不等于最优。
`hardFeasibleRate` 是成功返回运行的可行比例；失败与缺失次数同时展示，避免幸存者统计误读。
不能直接用“阶段 2 总服务更大”比较不同第一阶段公平门槛下的优化质量。

MATLAB 调用 `leo_plot_benchmark` 出图，或用 `run_leo_plot_results` 从已有 MAT 重画，输出 PNG/PDF/FIG。
`makePlots=false` 仍导出全部绘图数值。本云环境只有 Octave CLI、无图形后端；完整图组由
`tools/render_plot_specs.py` 渲染 MATLAB 导出的 `plot_specs.json`，统计口径只在 MATLAB 中定义。
旧版 `comparison.png` 与 `tools/plot_benchmark_csv.py` 保留用于之前的实验；新图组说明见 [PLOTS.md](PLOTS.md)。
