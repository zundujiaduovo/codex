# 完整方法与评价指标

运行 `RUN_COMPARISON.m`。默认同一 32 用户物理样本、每方法 12 秒端到端软预算、三个算法种子。算法可能提前停止，也可能少量超时；实际时间和状态均记录在 `runs.csv`。

12 项包括初始化基准、不同算法和参数消融，并非 12 种互相独立的算法：

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

不可用或失败会写入 `runs.csv` 的 status 和 message，图中显示 N/A；不参与成功结果中位数，也不会算成零。

`method_comparison.png`：最差保证 QoS 比例（封顶公平）、保证 QoS 达标用户比例、保证总速率、独立衰落平均总速率、核算耗时，以及逐用户保证 QoS 比例。多种子柱为中位数，误差线为最小到最大值；逐用户曲线为首个指定种子。

`additional_qos_metrics.png`：基于保证服务量的 Jain 指数 `(sum G)^2/(K*sum G^2)`，平均需求完成比例 `mean(min(1,G/q))`，独立衰落下平均用户 QoS 达标率，以及全部用户同时达标的周期频率。后两项来自固定日程后、另取的 1000 个独立衰落周期，是样本频率而非数学保证。

同目录 `01_performance` 至 `18_phase_results` 的 PNG/PDF/FIG 涵盖运行时间、实际迭代次数、上界与界差、收敛、调度矩阵、SINR、用户服务、SB 能量、切点消融和求解器状态；详见 [PLOTS.md](PLOTS.md)。CSV 与 MAT 保存每次原始记录、价格、日程、迭代等数据。

`fairness` 是最差用户保证服务与需求比例（在 1 封顶），`jainFairness` 是保证服务分配的 Jain 指数，两者并不相同。保证总速率与衰落仿真平均总速率分别给出。上界仅针对当前周期保证模型；不同方法各自固定公平门槛下的吞吐界不能直接当作同一个问题的精确最优值。

`theoretical_bound.png` 和 `theoretical_bound_by_run.csv`：统一全用户 QoS 达标门槛下，分别显示各方法的保证总服务、有效上界与最优差距区间；完整计算口径见 [THEORETICAL_BOUND.md](THEORETICAL_BOUND.md)。
