# V12：优化目标与 V10/V11 的差异

V12 从 V11 `37bbe3d72cbb13b26fa1e6a5384391afddd64020` 开发。32 用户、20 个固定块、100 个基本时隙、最多 8 人并发、码本、用户位置及冻结的概率保证服务模型均沿用。优化目标改为未封顶的两阶段公平优先目标。

## 定义

令 `X` 为满足用户可用性、每块最多 L 人和同波束冲突等硬约束的完整二元日程集合。每个用户的周期保证服务为

`G_i(x) = max(0, sum_t a_it(x) - margin_i)`，

其中 `a_it` 包含冻结的服务斜率、有效数据时长和原 SINR 对数速率。先跨全部时隙求和，再扣一次周期风险余量；`q_i>0` 为原需求。

第一阶段求解

`s* = max_{x in X} min_i G_i(x)/q_i`。

没有 `s<=1` 的约束。第一阶段取得日程 `x1` 后，记录 `s0=min_i G_i(x1)/q_i`；第二阶段求解

`max_{x in X} sum_i G_i(x), subject to G_i(x)/q_i >= s0 for every i`。

代码严格按原模型的逐用户比例验收，不将 `s0` 改回 1，也不通过容差降低门槛。第二阶段保留 `x1` 作为可行初值，总保证服务不低于 `x1`。
本实现采用有时间预算的启发式搜索，因此 `s0` 是实际取得的可行值。只有原模型公平上下界闭合到声明容差，才确认第一阶段接近全局最优。`optimal=false` 不会因 SB 能量停滞或迭代结束而改变。

一个二用户例子说明目标变化：日程 A 的累计服务为 `(10,1.1)`，日程 B 为 `(4,4)`，需求都是 1。
旧目标把公平都记为 1，选择总服务 11.1 的 A；V12 比较公平 1.1 和 4，选择总服务 8 的 B。第二阶段不得为了更多总服务从 B 退回 A。

## 代码对应

| 位置 | V12 行为 |
|---|---|
| `leo_service_totals` / `leo_fairness_from_ratios` | 原模型返回未封顶最小比例；另设 `qosCompletion` 保存封顶达标量 |
| `leo_form_problem` / `leo_form_proxy_milp` | `s` 上限采用有效无干扰有限界，允许大于 1 |
| `leo_price_weights` / `leo_original_upper_bound` | 辅助 `s` 和原公平上界使用同一有限界，去掉数学上的 1 封顶 |
| `leo_v12_solve_schedule` / `leo_v12_run_price_phase` | 全员达标后继续公平搜索；第二阶段固定实际取得的 `s0` |
| `leo_solve_original_search` | 原式 Tabu 的公平评分和阶段门控同样适用新目标 |
| `leo_service_is_better` / `leo_recover_schedule` | 原式公平择优；第二阶段逐用户满足 `s0` 才接受吞吐改进 |
| `leo_exhaustive_search` | 小模型按未封顶公平、总保证服务字典序穷举 |
| `run_leo_v12_verify_exports` | 从完整 CSV 日程还原原模型成绩，复核公平未封顶及阶段门槛保持 |

`p.problem.objectiveMode='lexicographic_max_min'` 选择 V12。`leo_v12_parameters` 沿用旧论文场景并显式设置此目标。
默认参数也采用新目标；历史 `leo_paper_parameters` 和 V11 入口显式选择 `full_qos_sum`，无目标标记的旧模型继续按历史封顶规则解释。新实验目录含版本和完整协议校验。
通用 `run_leo_benchmarks` 及直接 `leo_benchmark_case` 也按原模型目标选择默认 SB/Local 适配版本；通用图形数据明确记录目标并标注未封顶公平。
`requireFullQos` 仅控制历史目标，不能在 V12 中把阶段二门槛强制改为 1。

保留原 9 个 V8 冻结文件及快照校验。V12 的代理和阶段循环使用另命名的适配文件，内层 SB/Local 核心沿用冻结实现；不将修改后的目标继续称为原封不动的 V8 搜索。

## 上界和可以作出的结论

第一阶段的 `leo_fairness_certificate` 对原始保证服务模型进行独立列生成和二元分支，给出 `L_s <= s* <= U_s`。
下界是按原公式评价的完整可行二元日程，分数主问题仅用于上界；每块定价覆盖完整合法组域。未完成枚举时仍返回有效无干扰上界。
`gapTargetMet`、未处理节点和停止状态完整导出。证书阶段发现的日程与被测方法的成绩分列，不回流辅助方法搜索。

正公平时，`G_i>=s*q_i` 等价于未截断累计服务 `A_i>=margin_i+s*q_i`；公平值为零的情形单独保留零界。
测试包含整数公平为零、分数松弛为正的反例，要求分支或保留未闭合差距。

令 `Smax` 为逐用户无干扰服务上界除以需求后取最小值。对任意非负乘子 `lambda`，完整合法组定价给出

`U(lambda) = max(0, Smax*max(0,1-sum(lambda)) + sum_m max_g sum_i lambda_i*A_im(g)/q_i - sum_i lambda_i*margin_i/q_i)`。

正公平可行日程的拉格朗日值不小于其公平值，因此该式是原模型上界；外层 `max(0,...)` 覆盖最大公平只能为零的情形。全部块完成定价才更新界，并加向上数值裕量。这里没有使用二次代理的候选分数作为全局上界。

第二阶段的 `leo_theory_bound` 在 V12 中必须显式传入 `fairnessFloor=s0`，返回该门槛下的总服务上下界。证书目标和可行性检查都采用 `s0*q_i`，缓存也绑定该门槛。
不同方法取得不同 `s0` 时，对应不同第二阶段可行域，总服务不直接作为同一吞吐问题排名。零门槛时使用保留 `max(0,...)` 截断安全性的粗界，不用扣除全员风险余量的有符号目标冒充上界。

V10/V11 约 115 Mbit/周期的共同上界针对全员 `G_i>=q_i` 时的总保证服务。它不能证明 V12 的最大公平值，也不是随机衰落平均吞吐的上界。
V12 的主证据是未封顶公平及其原模型上下界；第二阶段总服务由明确的 `s0` 条件解释。

## 运行协议和输出

默认比较原目标 Tabu、SB V12、配对 Local V12，共用同一场景、初始日程、搜索种子、物理候选域和每方法 120 秒端到端预算。
公平阶段使用搜索预算的 70%，其余用于固定 `s0` 的吞吐阶段；不会因达到 1 而提前切换。有限原子操作结束后检查时间，实际超时量记录在 CSV。
Tabu 不使用二次代理；SB/Local 使用相同的二次外层，最终候选都由原保证服务评价器验收。
默认一个种子，支持显式多搜索种子；配对结果可恢复，第一种子的两阶段六联图自动显示。

`run_leo_v12_comparison(out,o,true)` 保存并绘图；`run_leo_v12_show_results(out)` 只打开已有图或从 JSON 重画。
`run_leo_v12_summary(out,true)` 读取配对、复核和重新汇总，已保存证书按模型和协议复用；不重跑方法。
`runs.csv` 中 `stage1Fairness`、`stage2Fairness`、`requiredFairnessFloor`、`fairnessPreserved` 是核心复核列；`stage1CertificateConfirmed` 表示达到独立公平证书容差，不能由 QoS 达标率替代。
