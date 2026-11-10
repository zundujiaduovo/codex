> **V9 当前实现：** 默认8项、每方法120秒；主指标为全员QoS约束下的保证总服务和相对上界差距。候选池、两块协调、无二次Tabu、真正生效的参考点消融及新日志见 [V9_METHOD.md](V9_METHOD.md)。下文版本标注的旧预算、方法数量和图组说明保留作历史接口背景。

# 完整方法与评价指标

V6 默认运行 14 项基础 MATLAB 方法/消融；以下 16 项列表另含可选外部 MIQP/MILP，默认排除这两项。运行 `RUN_COMPARISON.m`。默认同一 32 用户物理样本、每方法 12 秒端到端软预算、固定算法种子71669974。算法可能提前停止，也可能少量超时；实际时间和状态均记录在 `runs.csv`。

16 项包括初始化基准、不同算法和参数消融，并非 16 种互相独立的算法：

1. `initial`：共同初始化。
2. `original_greedy`：需求缺口优先贪心。
3. `original_exchange`：增删、替换及跨块交换。
4. `original_tabu`：原目标禁忌搜索。
5. `price_sb`：两阶段价格协调加 SB。
6. `price_local`：价格协调加局部搜索，SB 内层消融。
7. `price_miqp`：价格协调加 Gurobi MIQP；需要 Gurobi 接口和许可。
8. `proxy_milp`：周期代理 MILP；需要 MATLAB intlinprog 或 Octave GLPK。
9. `sb_zero`：零干扰切点。
10. `sb_minimax_fixed`：固定 minimax 切点。
11. `sb_current_fixed`：固定当前日程切点。
12. `sb_reference_portfolio`：多切点搜索组合，预算在成员之间分配。

另外增加 `price_sb_blockwise`、`price_sb_adaptive`、`price_sb_light`、`price_local_adaptive`；逐块验收和切点刷新的具体口径见 [ADAPTIVE_SB.md](ADAPTIVE_SB.md)。

V6 目标状态单列：`full_qos_met` 表示所有用户 G_i>=q_i，`full_qos_not_found` 只表示未找到达标日程。程序完成状态 `completed` 不表示业务目标完成。`feasibleTotalBits` 只在全员达标时填值，主吞吐图使用此列；`totalBits` 保留未达标诊断日程。`requiredFairnessFloor=1` 是统一门槛。`summary.csv` 另有 `fullQosMet` 和 `medianFeasibleTotalBits`。

如果共同初始化已经全员达标，公平搜索阶段不会运行；`sb_zero`、`sb_minimax_fixed`、`sb_current_fixed` 的第一阶段切点差异此时未被触发，结果相同是预期行为，不能把它们当成独立算法证据。

不可用或失败会写入 `runs.csv` 的 status 和 message，图中显示 N/A；不参与成功结果中位数，也不会算成零。

`method_comparison.png`：最差保证 QoS 比例（封顶公平）、保证 QoS 达标用户比例、保证总速率、独立衰落平均总速率、核算耗时，以及逐用户保证 QoS 比例。多种子折线点为中位数，误差线为最小到最大值；逐用户曲线为首个指定种子。

`additional_qos_metrics.png`：基于保证服务量的 Jain 指数 `(sum G)^2/(K*sum G^2)`，平均需求完成比例 `mean(min(1,G/q))`，独立衰落下平均用户 QoS 达标率，以及全部用户同时达标的周期频率。后两项来自固定日程后、另取的 1000 个独立衰落周期，是样本频率而非数学保证。

同目录 `01_performance` 至 `18_phase_results` 的 PNG/PDF/FIG 涵盖运行时间、实际迭代次数、上界与界差、收敛、调度矩阵、SINR、用户服务、SB 能量、切点消融和求解器状态；详见 [PLOTS.md](PLOTS.md)。CSV 与 MAT 保存每次原始记录、价格、日程、迭代等数据。

`fairness` 是最差用户保证服务与需求比例（在 1 封顶），`jainFairness` 是保证服务分配的 Jain 指数，两者并不相同。保证总速率与衰落仿真平均总速率分别给出。上界仅针对当前周期保证模型；V6 主入口统一全员公平门槛为1；历史入口的不同公平门槛不能混作同一问题。

`theoretical_bound.png` 和 `theoretical_bound_by_run.csv`：统一全用户 QoS 达标门槛下，分别显示各方法的保证总服务、有效上界与最优差距区间；完整计算口径见 [THEORETICAL_BOUND.md](THEORETICAL_BOUND.md)。


V7上界采用CERTIFICATE_SEARCH.md中的列生成/分支定价，证书整数下界可能来自额外certificate_search，不属于某一被测方法。默认价格方法的轮数上限提高到1000，仍受12秒软预算；日志Stop区分time_limit、iteration_limit和bound_gap。上界summary新增relativeGap、gapTargetMet、nodesProcessed、openNodeCount及rootRelaxationUpperBits。目标差距默认0.01%，未达到时不得宣称已精确最优。


V8默认在结果目录的sb_convergence下导出每种SB独立收敛图与汇总时间对照；run_leo_sb_convergence也可读取已有V7文件。新日志记录逐块验收、价格日程验收、恢复返回和阶段结束的已保存值；不改变搜索规则。sb_convergence_time.csv保留实际核算时间，sb_convergence_rounds.csv保留阶段/成员局部轮数，sb_convergence_energy.csv保留各固定代表调用的能量，图不将不同Ising问题拼成一条能量曲线。
