# 函数索引与调用关系

所有公开 `.m` 函数均含中文输入、输出说明。MATLAB 中执行 `help 函数名` 可直接查看。

维度约定：K 为用户数，M 为固定时间块数，T 为基本槽数，NB=32 为码本大小，L=8 为最大并发人数。
`x` 通常为 K×M；资源内层的局部 `x` 为 nUsers×1。功率 W、带宽 Hz、时间 s、服务 bit；dB 字段单独标明。
`problem.data` 是固定的原始设计模型；`proxy.lower/upper` 含 aBits(K×M)、bBits(K×K×M)。
全周期验收调用 `leo_evaluate_service`；瞬时随机信道 SINR 不参与统计 CSI 调度的原始设计评分。

主调用链：`run_leo_sinr → leo_form_problem → leo_build_service_surrogates → leo_solve_schedule → leo_run_price_phase → leo_solve_resource`。
对比链：`run_leo_benchmarks → leo_benchmark_case → leo_run_benchmark_method → 各基线 → leo_export_benchmark`。

绘图链：`run_leo_plot_results → leo_collect_plot_data → leo_build_plot_specs → leo_render_plot_specs`；图表与迭代口径见 PLOTS.md。

| 函数 | 作用 / 方案位置 |
|---|---|
| [leo_array_response](matlab/leo_array_response.m) | [C1] 每列单位范数，p 索引优先变化，与码本一致。 |
| [leo_assemble_quadratic_service](matlab/leo_assemble_quadratic_service.m) | T5-T6：a_i*x_i - sum_{j~=i}b_ij*x_i*x_j。 |
| [leo_assign_beams](matlab/leo_assign_beams.m) | [G5-G6] 整资源同一码字最大化最差增益，只做物理过滤。 |
| [leo_ballistic_sb](matlab/leo_ballistic_sb.m) | 多轨迹 ballistic simulated bifurcation，无额外工具箱。 |
| [leo_benchmark_case](matlab/leo_benchmark_case.m) | 第 13.3 节：同一物理样本上的多算法、多随机种子对比。 |
| [leo_benchmark_options](matlab/leo_benchmark_options.m) | 第 13.3 节统一实验设置：同输入、同种子、同端到端时间上限。 |
| [leo_budget_expired](matlab/leo_budget_expired.m) | 软时间预算；每个有限原子操作完成后检查。 |
| [leo_build_codebook](matlab/leo_build_codebook.m) | [C5-C8] 固定网格、有限相位、首阵元归零、稳定去重。 |
| [leo_build_hard_constraints](matlab/leo_build_hard_constraints.m) | O1：x(:) 按 MATLAB 列优先，资源内用户连续。 |
| [leo_build_plot_specs](matlab/leo_build_plot_specs.m) | 生成完整图组的数值规格，MATLAB/Python 共用同一数据和口径。 |
| [leo_build_resource_qubo](matlab/leo_build_resource_qubo.m) | L4、Q1-Q4、M3：E=C+z'*Qsym*z，z=[用户位;松弛位]。 |
| [leo_build_resources](matlab/leo_build_resources.m) | [S2-S4] 连续不重叠固定资源、开销及槽内采样时刻。 |
| [leo_build_service_surrogates](matlab/leo_build_service_surrogates.m) | 第 7.1-7.5 节：切线下界、弦线上界、二次系数和误差。 |
| [leo_call_milp](matlab/leo_call_milp.m) | MATLAB intlinprog / Octave GLPK 适配，不掩盖求解器缺失或超时。 |
| [leo_check_codebook_coverage](matlab/leo_check_codebook_coverage.m) | 对固定扫描域抽样检查真实量化方向图。 |
| [leo_check_problem_point](matlab/leo_check_problem_point.m) | 对完整变量向量检查上下界、整数、线性和 QoS。 |
| [leo_check_surrogate_groups](matlab/leo_check_surrogate_groups.m) | 枚举各资源全部合法组，检查每用户的服务夹逼和误差。 |
| [leo_chord_upper](matlab/leo_chord_upper.m) | T7-T10：单个速率函数在 [a,b] 上的弦上界与 minimax 切点。 |
| [leo_collect_plot_data](matlab/leo_collect_plot_data.m) | 整理同口径绘图数据；不运行优化、不补造缺失迭代。 |
| [leo_compare_schedules](matlab/leo_compare_schedules.m) | 所有对照使用同一个问题和设计服务口径，不重新分配风险。 |
| [leo_compute_geometry](matlab/leo_compute_geometry.m) | [G3-G4] 斜距、仰角、阵列出射方向、正面扫描条件。 |
| [leo_compute_sinr](matlab/leo_compute_sinr.m) | [P1,P3,P5-P6] 给定 KxM 合法二元选择矩阵的瞬时 SINR。 |
| [leo_default_parameters](matlab/leo_default_parameters.m) | 参数集中入口；SI 单位，角度字段以 Deg 结尾。 |
| [leo_encode_group_bits](matlab/leo_encode_group_bits.m) | 在修复用户组后重新编码松弛位，绝不沿用 SB 原始松弛位。 |
| [leo_enumerate_resource_groups](matlab/leo_enumerate_resource_groups.m) | 列出所有合法二元组，第一列是空组。 |
| [leo_evaluate_quadratic_service](matlab/leo_evaluate_quadratic_service.m) | 评价单个二次服务表达式，不裁剪负下界。 |
| [leo_evaluate_service](matlab/leo_evaluate_service.m) | R5-R6、O3-O4：原始设计速率及跨块累计服务（bit）。 |
| [leo_evaluate_service_bounds](matlab/leo_evaluate_service_bounds.m) | 对同一合法完整日程比较下界、原始服务、上界。 |
| [leo_example_selection](matlab/leo_example_selection.m) | 仅演示合法选组：按用户编号轮换，同波束至多一人。 |
| [leo_exhaustive_options](matlab/leo_exhaustive_options.m) | 穷举保护参数；超限明确返回，不缩小原问题或抽样。 |
| [leo_exhaustive_search](matlab/leo_exhaustive_search.m) | 完整日程穷举，原始 O2/O4 字典序全局对照。 |
| [leo_exhaustive_size](matlab/leo_exhaustive_size.m) | 合法组数 Gm 与完整日程数 prod(Gm)，不生成候选组。 |
| [leo_export_benchmark](matlab/leo_export_benchmark.m) | 导出实验 CSV/MAT 及全部可重画数值，包含迭代/价格/SB 能量日志。 |
| [leo_export_plot_data](matlab/leo_export_plot_data.m) | 导出绘图输入、迭代/时间/价格/能量 CSV 和跨渲染器 JSON。 |
| [leo_form_problem](matlab/leo_form_problem.m) | 第 6 节 O1-O4：形成原始非线性混合整数问题，不求解。 |
| [leo_form_proxy_milp](matlab/leo_form_proxy_milp.m) | 第 13.3 节：直接线性化二次下界的完整周期 MILP。 |
| [leo_form_stage2](matlab/leo_form_stage2.m) | 2 O4：用给定可行日程的实际设计公平值形成第二阶段。 |
| [leo_generate_fading](matlab/leo_generate_fading.m) | [C3-C4] 几何共同方向的归一化 Rician 瞬时样本。 |
| [leo_generate_users](matlab/leo_generate_users.m) | 固定用户：先在球面帽均匀取点，再用 WGS-84 转 ECEF。 |
| [leo_geodetic_to_ecef](matlab/leo_geodetic_to_ecef.m) | [G1-G2] WGS-84 大地坐标与椭球向上法向，输出 3xK。 |
| [leo_initial_schedules](matlab/leo_initial_schedules.m) | 空/预检见证/用户提供/需求轮转/随机可行起点；不读取穷举。 |
| [leo_interference_limits](matlab/leo_interference_limits.m) | T2-T3：条件 x_i=1 下，其他不同波束中最大的 L-1 项。 |
| [leo_large_scale_channel](matlab/leo_large_scale_channel.m) | [C2,P4] 单阵元 beta、自由空间损耗、kB*Tsys*B。 |
| [leo_link_coefficients](matlab/leo_link_coefficients.m) | [P5] 与选择组无关的有用系数及用户-波束干扰系数。 |
| [leo_method_options](matlab/leo_method_options.m) | 配置 A：全物理候选域、两阶段拉格朗日 + ballistic SB。 |
| [leo_original_greedy](matlab/leo_original_greedy.m) | 第 13.3 节：需求缺口优先，按原始服务选择最佳可加块。 |
| [leo_original_neighbors](matlab/leo_original_neighbors.m) | 第 13.3 节：生成原目标可行增删/替换及跨块交换邻域。 |
| [leo_original_upper_bound](matlab/leo_original_upper_bound.m) | E4/E6 + UB1，有效原问题上界，独立于 SB 近似质量。 |
| [leo_plot_benchmark](matlab/leo_plot_benchmark.m) | 完整对比图入口：迭代、收敛、性能、资源及代理诊断共 18 图。 |
| [leo_polish_group](matlab/leo_polish_group.m) | 可行组上的二次收益 add/drop/swap，严格单调、有限动作。 |
| [leo_precheck_positive_fairness](matlab/leo_precheck_positive_fairness.m) | O2/6.4：最大流检查每用户至少一次正服务。 |
| [leo_predict_orbit](matlab/leo_predict_orbit.m) | 连续圆轨道 ECI -> ECEF；合成星历，不是 TLE/SGP4。 |
| [leo_prepare_design_service](matlab/leo_prepare_design_service.m) | R1-R7：所有候选用户-基本槽的风险与设计系数。 |
| [leo_prepare_upper_bounds](matlab/leo_prepare_upper_bounds.m) | UB1：按组基数 n，取其他波束中最小 n-1 个干扰。 |
| [leo_price_weights](matlab/leo_price_weights.m) | L3-L5、V3：阶段 1 的 s 辅助解与两阶段非负用户权重。 |
| [leo_problem_nonlcon](matlab/leo_problem_nonlcon.m) | 原始非线性累计 QoS，统一 c<=0；不含切线近似。 |
| [leo_problem_objective](matlab/leo_problem_objective.m) | 最小化接口：阶段 1 为 -s，阶段 2 为 -sum(D)/Dref。 |
| [leo_qubo_to_ising](matlab/leo_qubo_to_ising.m) | Q5：z=(1+sigma)/2，E=C'+h'*sigma+sigma'*J*sigma/2。 |
| [leo_rate_and_derivatives](matlab/leo_rate_and_derivatives.m) | T1：设计速率及对干扰功率 I（W）的导数。 |
| [leo_record_search_step](matlab/leo_record_search_step.m) | 记录原目标搜索的已保存可行值，不改变选择/验收规则。 |
| [leo_recover_schedule](matlab/leo_recover_schedule.m) | 12.2：整周期原始服务的有限 add/drop/replace/跨资源交换。 |
| [leo_render_plot_specs](matlab/leo_render_plot_specs.m) | 基础 MATLAB 绘制全部规格，导出 PNG/PDF/可编辑 FIG。 |
| [leo_repair_group](matlab/leo_repair_group.m) | 按最小二次收益损失删除冲突者，再删除超出容量者。 |
| [leo_resource_group_services](matlab/leo_resource_group_services.m) | R5-R6：一次计算所有合法组在一个资源的服务。 |
| [leo_resource_service](matlab/leo_resource_service.m) | 第 13.3 节：单个可行组只重算至多 L 个活跃用户。 |
| [leo_rician_power_cdf](matlab/leo_rician_power_cdf.m) | R2：归一化 Rician 功率的 CDF，无统计工具箱依赖。 |
| [leo_rician_power_quantile](matlab/leo_rician_power_quantile.m) | R2 低分位；二分返回 CDF 上界不超过 eps 的下端。 |
| [leo_run_benchmark_method](matlab/leo_run_benchmark_method.m) | 第 13.3 节实验分派；所有求解均只收到同一模型/初始化。 |
| [leo_run_price_phase](matlab/leo_run_price_phase.m) | 两阶段共用价格循环；内层、恢复、原始验收和有效上界分开。 |
| [leo_schedule_interference](matlab/leo_schedule_interference.m) | 合法完整日程的设计干扰；包含未选用户的反事实接收值。 |
| [leo_select_codebook](matlab/leo_select_codebook.m) | 在用户生成前选定 NB 个码字，不依赖用户/日程/价格。 |
| [leo_service_is_better](matlab/leo_service_is_better.m) | 原始设计服务验收；阶段 2 不容忍降低固定公平门槛。 |
| [leo_solve_original_search](matlab/leo_solve_original_search.m) | 第 13.3 节：原始速率的 greedy/exchange/tabu 两阶段基线。 |
| [leo_solve_proxy_milp](matlab/leo_solve_proxy_milp.m) | 第 13.3 节：同一切线代理的直接 MILP 两阶段对照。 |
| [leo_solve_resource](matlab/leo_solve_resource.m) | 第 13.3 节：相同 L4 内层目标的 SB/局部搜索/MIQP 调度。 |
| [leo_solve_resource_local](matlab/leo_solve_resource_local.m) | 第 13.3 节：同一二次代理的多起点可行 add/drop/swap。 |
| [leo_solve_resource_miqp](matlab/leo_solve_resource_miqp.m) | 第 13.3 节：Gurobi 求解相同 L4 的受约束二元 MIQP。 |
| [leo_solve_resource_sb](matlab/leo_solve_resource_sb.m) | 资源 QUBO -> Ising -> 多轨迹 SB -> 修复 -> 代理计分。 |
| [leo_solve_schedule](matlab/leo_solve_schedule.m) | 第 8-12 节配置 A，原始设计模型上的两阶段启发式搜索。 |
| [leo_summarize_benchmark](matlab/leo_summarize_benchmark.m) | 第 13.3 节：分别统计成功/缺失/失败、典型值及最好完整运行。 |
| [leo_tangent_lower](matlab/leo_tangent_lower.m) | T4：ell(I)=alpha-omega*I，保留可能为负的切线值。 |
| [leo_update_prices](matlab/leo_update_prices.m) | L6/V4：使用价格子问题日程的下界服务，而非恢复/原始服务。 |
| [leo_validate_parameters](matlab/leo_validate_parameters.m) | 检查物理约束，并统一更新所有派生参数。 |
| [leo_write_struct_csv](matlab/leo_write_struct_csv.m) | 导出标量结构体表，UTF-8；字符串引号/逗号正确转义。 |
| [run_leo_benchmarks](matlab/run_leo_benchmarks.m) | 文档第 13.3 节统一对比主入口，固定 32 波束/最多 8 人。 |
| [run_leo_exhaustive_demo](matlab/run_leo_exhaustive_demo.m) | 可实际完成的穷举对照：8 用户，3 个 50 ms 资源。 |
| [run_leo_method_demo](matlab/run_leo_method_demo.m) | 默认 8 用户/3 个固定块，与原问题完整穷举对照。 |
| [run_leo_plot_results](matlab/run_leo_plot_results.m) | 从已保存结果重画全部图，无需再次运行优化算法。 |
| [run_leo_sinr](matlab/run_leo_sinr.m) | 主入口：建模、代理；可选两阶段拉格朗日 SB 和原始问题穷举。 |
| [run_leo_surrogate_demo](matlab/run_leo_surrogate_demo.m) | 在原 8 用户/3 块穷举小例上验证切线与弦线。 |
| [test_leo_benchmark](matlab/test_leo_benchmark.m) | 对比可信性：原始增量服务、零切点、MILP 等价性、预算和共同初始化。 |
| [test_leo_exhaustive](matlab/test_leo_exhaustive.m) | 以独立全二元位枚举核对穷举算法，不使用同一组生成器。 |
| [test_leo_method](matlab/test_leo_method.m) | 精确位串/组枚举验证能量、硬约束、有效界及两阶段原始服务验收。 |
| [test_leo_model](matlab/test_leo_model.m) | 无附加工具箱测试，包含独立复矩阵接收功率核对。 |
| [test_leo_plots](matlab/test_leo_plots.m) | 验证图表计数、真实时间、有效界、SB 能量、缺失值和导出接口。 |
| [test_leo_problem](matlab/test_leo_problem.m) | 原始问题形成检查；独立 CDF 数值、直接接收功率、枚举硬约束。 |
| [test_leo_surrogate](matlab/test_leo_surrogate.m) | 凸性、minimax、硬约束干扰区间、二次系数、参考点和边界检查。 |

## leo_array_response

```matlab
function a = leo_array_response(p,direction)
```

接口标注：
输入：p：UPA 参数；direction：3×N 阵列坐标系单位方向。
输出：a：Na×N 单位范数复阵列响应。

直接调用：基础 MATLAB 运算。
调用入口：`leo_assign_beams`, `leo_build_codebook`, `leo_check_codebook_coverage`, `leo_select_codebook`。

## leo_assemble_quadratic_service

```matlab
function q = leo_assemble_quadratic_service(data,alphaBps,omegaBpsPerW)
```

接口标注：
输入：data：模型；alphaBps/omegaBpsPerW：K×T 仿射速率系数。
输出：q：K×M aBits、K×K×M 有向 bBits，逐基本槽精确累加。
b 是有向用户干扰损失，通常不对称；对角严格为零，不新增二进制变量。

直接调用：基础 MATLAB 运算。
调用入口：`leo_build_service_surrogates`。

## leo_assign_beams

```matlab
function b = leo_assign_beams(p,r,g,cb)
```

接口标注：
输入：p/r/g/cb：参数、固定资源、预测几何、冻结码本。
输出：b：K×M 可用掩码/预指派码字，以及 K×NB×T 实际增益。

直接调用：`leo_array_response`。
调用入口：`run_leo_sinr`, `test_leo_model`。

## leo_ballistic_sb

```matlab
function result = leo_ballistic_sb(ising,options,seeds,budget)
```

接口标注：
输入：ising：J/h；options：轨迹/积分参数；seeds：位种子；budget：软时间上限。
输出：result：每轨迹最佳位/能量、实际积分步、尺度、超时状态及检查点能量 history。
无量纲 a0=1；线性泵浦 0->1；辛 Euler；|position|>1 时非弹性壁。
J 和 h 使用同一个正数归一化，保持能量相对尺度和符号。
返回每条轨迹检查点上最小离散能量，属于启发式结果。

直接调用：`leo_budget_expired`。
调用入口：`leo_solve_resource_sb`, `test_leo_method`, `test_leo_plots`。

## leo_benchmark_case

```matlab
function report = leo_benchmark_case(model,options)
```

输入：run_leo_sinr 的未求解模型、实验选项；输出逐次记录、日程、统计及穷举参考。
共用预处理耗时按每个方法各记一次；穷举在所有启发式结束后运行，禁止先验泄漏。

直接调用：`leo_benchmark_options`, `leo_exhaustive_options`, `leo_exhaustive_search`, `leo_run_benchmark_method`, `leo_summarize_benchmark`。
调用入口：`run_leo_benchmarks`, `test_leo_benchmark`, `test_leo_plots`。

## leo_benchmark_options

```matlab
function o = leo_benchmark_options(overrides)
```

输入：可选覆盖结构；输出：方法列表、重复种子、预算及结果目录等实验参数。

直接调用：`leo_method_options`。
调用入口：`leo_benchmark_case`, `run_leo_benchmarks`, `test_leo_benchmark`, `test_leo_plots`。

## leo_budget_expired

```matlab
function expired = leo_budget_expired(budget)
```

接口标注：
输入：budget：含 tic 句柄 timer 和秒数 seconds；[] 表示不设限。
输出：expired：逻辑标量，已达软时间上限。

直接调用：基础 MATLAB 运算。
调用入口：`leo_ballistic_sb`, `leo_initial_schedules`, `leo_original_greedy`, `leo_original_neighbors`, `leo_recover_schedule`, `leo_run_price_phase`, `leo_solve_original_search`, `leo_solve_proxy_milp`, `leo_solve_resource_local`, `leo_solve_resource_miqp`, `leo_solve_resource_sb`, `leo_solve_schedule`。

## leo_build_codebook

```matlab
function cb = leo_build_codebook(p)
```

接口标注：
输入：p：固定候选网格、量化位数、码本大小。
输出：cb：Na×NB 合法复码字及对应方向元数据。
不读取用户/轨道。以 (r,s) 字典序编号；量化平局采用 MATLAB round。

直接调用：`leo_array_response`, `leo_select_codebook`。
调用入口：`run_leo_sinr`, `test_leo_problem`。

## leo_build_hard_constraints

```matlab
function hard = leo_build_hard_constraints(p,r,b)
```

接口标注：
输入：p/r/b：人数/固定块/波束可用性。
输出：hard：x(:) 的稀疏 A/rhs、上下界、整数索引；列优先排列。

直接调用：基础 MATLAB 运算。
调用入口：`leo_form_problem`, `test_leo_problem`。

## leo_build_plot_specs

```matlab
function figures = leo_build_plot_specs(data)
```

输入：leo_collect_plot_data 输出；输出：图名、子图、曲线、误差范围、热图等结构数组。
柱为多种子中位数，误差棒为最小至最大；非置信区间。缺失值保持 NaN。

直接调用：基础 MATLAB 运算。
调用入口：`leo_export_plot_data`, `test_leo_plots`。

## leo_build_resource_qubo

```matlab
function qubo = leo_build_resource_qubo(data,lower,m,weights,options)
```

接口标注：
输入：data/lower：模型及下界；m：块号；weights：K×1；options：罚权/松弛选项。
输出：qubo：局部用户索引、A/B、对称/上三角 QUBO、常数与松弛位。
只删除物理不可用变量；同波束用成对冲突罚，不强制每波束激活。

直接调用：`leo_method_options`。
调用入口：`leo_solve_resource_local`, `leo_solve_resource_miqp`, `leo_solve_resource_sb`, `test_leo_method`, `test_leo_plots`。

## leo_build_resources

```matlab
function r = leo_build_resources(p)
```

接口标注：
输入：p：已校验参数。
输出：r：M 个固定块、槽到块映射、采样时刻及净数据时间 s。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`, `test_leo_benchmark`, `test_leo_exhaustive`, `test_leo_method`, `test_leo_model`, `test_leo_plots`, `test_leo_surrogate`。

## leo_build_service_surrogates

```matlab
function proxy = leo_build_service_surrogates(problem,mode,x0)
```

接口标注：
输入：problem：原问题；mode：minimax/zero/current_schedule；x0：仅相切模式需要。
输出：proxy：切线/弦线、二次 a/b、合法区间、服务误差 bit 及公平误差界。
mode='minimax'（默认）、'zero' 或 'current_schedule'；后者需合法参考日程 x0。

直接调用：`leo_assemble_quadratic_service`, `leo_chord_upper`, `leo_evaluate_quadratic_service`, `leo_interference_limits`, `leo_rate_and_derivatives`, `leo_schedule_interference`, `leo_tangent_lower`。
调用入口：`leo_collect_plot_data`, `leo_run_price_phase`, `leo_solve_proxy_milp`, `leo_solve_schedule`, `run_leo_sinr`, `run_leo_surrogate_demo`, `test_leo_benchmark`, `test_leo_method`, `test_leo_plots`, `test_leo_surrogate`。

## leo_call_milp

```matlab
function result = leo_call_milp(model,seconds)
```

输入：leo_form_proxy_milp 输出、剩余秒数；输出变量、状态、最优性、called 与实际报告的 nodes。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_proxy_milp`, `test_leo_benchmark`。

## leo_check_codebook_coverage

```matlab
function c = leo_check_codebook_coverage(p,cb)
```

接口标注：
输入：p：扫描验证网格、覆盖门槛；cb：实际有限码本。
输出：c：抽样最优增益、空洞比例；不是连续扫描域证明。

直接调用：`leo_array_response`。
调用入口：`run_leo_sinr`。

## leo_check_problem_point

```matlab
function report = leo_check_problem_point(stage,z,tolerance)
```

接口标注：
输入：stage：问题模板；z：候选向量；tolerance：检查容差。
输出：report：边界、整数、线性及 QoS 约束的违反量/可行性。

直接调用：基础 MATLAB 运算。
调用入口：`leo_exhaustive_search`, `test_leo_problem`。

## leo_check_surrogate_groups

```matlab
function report = leo_check_surrogate_groups(problem,proxy,maxGroupsPerResource)
```

接口标注：
输入：problem/proxy：原模型及代理；maxGroupsPerResource：枚举保护上限。
输出：report：各资源全部合法组的夹逼/误差检查及覆盖组合规模。
服务跨资源可加，因此各资源全组通过即覆盖其笛卡尔积中的所有完整日程。
不声称直接遍历了完整日程；大规模需显式限额。

直接调用：`leo_enumerate_resource_groups`, `leo_exhaustive_size`, `leo_resource_group_services`。
调用入口：`run_leo_surrogate_demo`, `test_leo_surrogate`。

## leo_chord_upper

```matlab
function line = leo_chord_upper(S,N,B,a,b)
```

接口标注：
输入：S/N：固定功率 W；B：Hz；a/b：干扰区间端点 W。
输出：line：弦系数、minimax 切点、最大误差 bit/s 与曲率界。
仅该区间内有上界保证。主模型始终用 [0,Imax] 覆盖全部合法激活干扰。

直接调用：`leo_rate_and_derivatives`。
调用入口：`leo_build_service_surrogates`, `test_leo_surrogate`。

## leo_collect_plot_data

```matlab
function data = leo_collect_plot_data(report)
```

输入：leo_benchmark_case/run_leo_benchmarks 的报告（兼容旧版无日志报告）。
输出：记录、分口径计数、全过程、代表种子日程及固定代理诊断数值。

直接调用：`leo_build_service_surrogates`, `leo_evaluate_quadratic_service`, `leo_evaluate_service`, `leo_rate_and_derivatives`。
调用入口：`leo_export_plot_data`, `test_leo_plots`。

## leo_compare_schedules

```matlab
function rows = leo_compare_schedules(problem,schedules,names)
```

接口标注：
输入：problem：同一模型；schedules：日程 cell；names：对应标签 cell。
输出：rows：各日程原始公平、总服务 bit 和每用户服务结构体表。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_exhaustive_demo`, `run_leo_method_demo`。

## leo_compute_geometry

```matlab
function g = leo_compute_geometry(p,u,o)
```

接口标注：
输入：p：覆盖门槛；u/o：用户与卫星轨道结构。
输出：g：K×T 距离、仰角、可见性及 3×K×T 阵列方向。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`。

## leo_compute_sinr

```matlab
function out = leo_compute_sinr(p,r,b,c,f,link,cb,x)
```

接口标注：
输入：p/r/b/c/f/link/cb：完整物理结构；x：K×M 合法二元日程。
输出：out：K×T 瞬时 SINR（线性及 dB）、激活掩码、信号/干扰功率 W。
非激活/无数据槽置零（导出约定）；必须同时用 active 掩码解释。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`, `test_leo_model`。

## leo_default_parameters

```matlab
function p = leo_default_parameters()
```

接口标注：
输入：无；修改返回结构后传给主入口。
输出：p：全部物理、资源、问题与算法参数；SI 单位。
数值来源/假设见 README.md；未将演示参数冒充论文复现实验。
[S1-S4] 系统、资源、功率；[G1-G6] 几何；[C1-C8] 信道及码本。

直接调用：`leo_exhaustive_options`, `leo_method_options`。
调用入口：`run_leo_benchmarks`, `run_leo_exhaustive_demo`, `run_leo_method_demo`, `run_leo_sinr`, `run_leo_surrogate_demo`, `test_leo_benchmark`, `test_leo_exhaustive`, `test_leo_method`, `test_leo_model`, `test_leo_plots`, `test_leo_problem`, `test_leo_surrogate`。

## leo_encode_group_bits

```matlab
function z = leo_encode_group_bits(qubo,x)
```

接口标注：
输入：qubo：局部编码；x：nUsers×1 合法用户组。
输出：z：用户位及重新编码的容量松弛位；二元列向量。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_resource_local`, `leo_solve_resource_miqp`, `leo_solve_resource_sb`, `test_leo_method`。

## leo_enumerate_resource_groups

```matlab
function groups = leo_enumerate_resource_groups(data,m,maxGroups)
```

接口标注：
输入：data：模型；m：块号；maxGroups：合法组数量保护阈值。
输出：groups：K×G 合法二元组，包括空组。
每波束选“不激活”或“恰好一位用户”，同时限制总人数；没有候选筛选。

直接调用：`leo_exhaustive_size`。
调用入口：`leo_check_surrogate_groups`, `leo_exhaustive_search`, `test_leo_exhaustive`, `test_leo_method`, `test_leo_surrogate`。

## leo_evaluate_quadratic_service

```matlab
function result = leo_evaluate_quadratic_service(data,q,x,requireFeasibleBinary)
```

接口标注：
输入：data：模型；q：aBits/bBits；x：K×M 日程；可选二元校验。
输出：result：二次服务 bit 及归一化公平，保留负下界。
requireFeasibleBinary=false 仅计算多项式值，不提供弦线/误差证书。

直接调用：基础 MATLAB 运算。
调用入口：`leo_build_service_surrogates`, `leo_collect_plot_data`, `leo_evaluate_service_bounds`, `leo_run_price_phase`, `test_leo_benchmark`, `test_leo_method`。

## leo_evaluate_service

```matlab
function service = leo_evaluate_service(data,x,requireFeasibleBinary)
```

接口标注：
输入：data：固定设计模型；x：K×M 日程；可选 requireFeasibleBinary。
输出：service：逐槽/逐块/逐用户 bit、最差需求比、公平和净总服务。
默认校验合法二元日程。false 仅供问题回调在 [0,1] 盒内计算连续延拓。

直接调用：基础 MATLAB 运算。
调用入口：`leo_collect_plot_data`, `leo_form_problem`, `leo_form_stage2`, `leo_precheck_positive_fairness`, `leo_problem_nonlcon`, `leo_problem_objective`, `leo_schedule_interference`, `test_leo_method`, `test_leo_problem`, `test_leo_surrogate`。

## leo_evaluate_service_bounds

```matlab
function result = leo_evaluate_service_bounds(problem,proxy,x)
```

接口标注：
输入：problem/proxy：原模型与同一模型代理；x：合法日程。
输出：result：下界、原始、上界服务及夹逼检查。

直接调用：`leo_evaluate_quadratic_service`。
调用入口：`run_leo_sinr`, `run_leo_surrogate_demo`, `test_leo_surrogate`。

## leo_example_selection

```matlab
function x = leo_example_selection(p,r,b)
```

接口标注：
输入：p/r/b：人数上限、资源与可用/波束约束。
输出：x：K×M 合法轮换示例，非公平优化结果。
SINR 必须给定激活组；此函数不是 QoS 调度或公平性算法。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`。

## leo_exhaustive_options

```matlab
function options = leo_exhaustive_options(overrides)
```

接口标注：
输入：overrides：可选规模、内存、批次及时间上限。
输出：options：完整穷举的保护配置，不自动缩小物理问题。

直接调用：基础 MATLAB 运算。
调用入口：`leo_benchmark_case`, `leo_default_parameters`, `leo_exhaustive_search`, `leo_validate_parameters`, `run_leo_exhaustive_demo`, `test_leo_exhaustive`。

## leo_exhaustive_search

```matlab
function result = leo_exhaustive_search(problem,overrides)
```

接口标注：
输入：problem：原问题；overrides：可选穷举预算。
输出：result：最优/超限/超时状态、已访问数量、最好合法日程及原始服务。
对所有资源合法组的笛卡尔积逐一评价；无剪枝、采样或逐块贪心。
先比较 min(1,min(D_i/q_i))，严格同分再比较总服务；不放宽公平门槛。

直接调用：`leo_check_problem_point`, `leo_enumerate_resource_groups`, `leo_exhaustive_options`, `leo_exhaustive_size`, `leo_resource_group_services`。
调用入口：`leo_benchmark_case`, `run_leo_sinr`, `test_leo_exhaustive`。

## leo_exhaustive_size

```matlab
function estimate = leo_exhaustive_size(data)
```

接口标注：
输入：data：每个资源的候选、波束归属与人数上限。
输出：estimate：合法组数、完整组合数、log10 规模与双精度精确计数标志。
若波束 b 有 nb 个用户，Gm=sum_{l=0}^L [z^l] prod_b(1+nb*z)。

直接调用：基础 MATLAB 运算。
调用入口：`leo_check_surrogate_groups`, `leo_enumerate_resource_groups`, `leo_exhaustive_search`。

## leo_export_benchmark

```matlab
function leo_export_benchmark(report,directory)
```

输入：对比报告、目录；输出：目录内文件，无函数句柄序列化依赖。

直接调用：`leo_export_plot_data`, `leo_write_struct_csv`。
调用入口：`run_leo_benchmarks`。

## leo_export_plot_data

```matlab
function [plotData,specs] = leo_export_plot_data(source,directory)
```

输入：对比报告或已收集 plotData、输出目录；输出：纯数值 plotData 与图形规格 specs。
无图形后端也能完成；后处理耗时不计入算法运行时间。

直接调用：`leo_build_plot_specs`, `leo_collect_plot_data`, `leo_write_struct_csv`。
调用入口：`leo_export_benchmark`, `leo_plot_benchmark`, `run_leo_plot_results`。

## leo_form_problem

```matlab
function problem = leo_form_problem(p,r,b,design)
```

接口标注：
输入：p/r/b/design：参数、资源、波束、设计服务系数。
输出：problem：原始两阶段问题回调、数据与可服务性预检；尚未求解。
不进行切线、拉格朗日、QUBO、SB；不加入第 20 节可选吞吐底线。

直接调用：`leo_build_hard_constraints`, `leo_evaluate_service`, `leo_form_stage2`, `leo_precheck_positive_fairness`, `leo_problem_nonlcon`, `leo_problem_objective`。
调用入口：`run_leo_sinr`, `test_leo_benchmark`, `test_leo_exhaustive`, `test_leo_method`, `test_leo_plots`, `test_leo_surrogate`。

## leo_form_proxy_milp

```matlab
function model = leo_form_proxy_milp(data,lower,phase,s0)
```

输入：data、lower、fairness/throughput、固定 s0；输出稀疏 f/A/b/lb/ub/intcon。
y_ijm=x_im*x_jm 用三个 McCormick 不等式；x 二元时 y 可保持连续。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_proxy_milp`, `test_leo_benchmark`。

## leo_form_stage2

```matlab
function stage = leo_form_stage2(data,x0)
```

接口标注：
输入：data：原问题数据；x0：K×M 已有合法日程。
输出：stage：以 x0 原始公平为固定门槛的 O4 模板。
不把输入日程当成第一阶段最优解，不进行优化求解。

直接调用：`leo_evaluate_service`, `leo_problem_nonlcon`, `leo_problem_objective`。
调用入口：`leo_form_problem`。

## leo_generate_fading

```matlab
function f = leo_generate_fading(p,g,b,c)
```

接口标注：
输入：p/g/b/c：参数、几何、波束、大尺度信道。
输出：f：复 Rician 样本、功率 Z、Na×K×T 瞬时复信道。
散射项默认用户/槽独立；这是块模型假设，不宣称真实时间相关性。
大时延和主多普勒已补偿；phi 保留传播相位作为一致的复信道约定。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`, `test_leo_model`。

## leo_generate_users

```matlab
function u = leo_generate_users(p)
```

接口标注：
输入：p：用户区域、数量及地球参数。
输出：u：固定用户经纬度、3×K ECEF 坐标 m 和局部法向。
球面帽仅用于区域采样，不能声称在椭球表面严格等面积。

直接调用：`leo_geodetic_to_ecef`。
调用入口：`run_leo_sinr`。

## leo_geodetic_to_ecef

```matlab
function [positionM, up] = leo_geodetic_to_ecef(latDeg,lonDeg,heightM,earth)
```

接口标注：
输入：latDeg/lonDeg/heightM：大地坐标；earth：WGS-84 参数。
输出：positionM、up：3×K ECEF 坐标 m 与单位向上向量。

直接调用：基础 MATLAB 运算。
调用入口：`leo_generate_users`, `test_leo_model`。

## leo_initial_schedules

```matlab
function initial = leo_initial_schedules(problem,provided,options,budget)
```

接口标注：
输入：problem：原模型；provided：可选已有日程；options/budget：随机种子及预算。
输出：initial：共同可行初始化中按原始公平/吞吐最好的日程与各起点成绩。

直接调用：`leo_budget_expired`, `leo_resource_group_services`, `leo_service_is_better`。
调用入口：`leo_solve_original_search`, `leo_solve_proxy_milp`, `leo_solve_schedule`。

## leo_interference_limits

```matlab
function limits = leo_interference_limits(data)
```

接口标注：
输入：data：完整物理候选域及每流固定功率。
输出：limits：条件选中用户的 K×T 合法干扰上限 W 与事件掩码。
同波束不同候选用户的固定系数相同，只计一个波束；排除用户自己的波束。

直接调用：基础 MATLAB 运算。
调用入口：`leo_build_service_surrogates`。

## leo_large_scale_channel

```matlab
function c = leo_large_scale_channel(p,g)
```

接口标注：
输入：p：链路及噪声参数；g：距离与几何。
输出：c：K×T 单阵元功率增益 beta、噪声功率 W。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`。

## leo_link_coefficients

```matlab
function link = leo_link_coefficients(p,r,b,c)
```

接口标注：
输入：p/r/b/c：固定功率、资源、预指派码字、信道。
输出：link：K×T 信号系数与 K×NB×T 用户—波束干扰系数 W。
beamPowerW(i,b,t) 使用受干扰用户 i 的 beta 和 a，保留全部旁瓣。
以后 cTilde(i,j,t)=beamPowerW(i,b.index(j,m),t)，只在 i~=j 时计干扰。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`。

## leo_method_options

```matlab
function o = leo_method_options(overrides)
```

接口标注：
输入：overrides：可选算法参数覆盖结构。
输出：o：校验后的价格、SB、修复、预算、内层求解器和切点设置。
步长/SB 参数是可调实验起点，不代表收敛或最优保证。

直接调用：基础 MATLAB 运算。
调用入口：`leo_benchmark_options`, `leo_build_resource_qubo`, `leo_default_parameters`, `leo_solve_original_search`, `leo_solve_proxy_milp`, `leo_solve_schedule`, `leo_validate_parameters`, `test_leo_benchmark`, `test_leo_method`, `test_leo_plots`。

## leo_original_greedy

```matlab
function result = leo_original_greedy(problem,start,phase,s0,budget)
```

输入：原问题、起点、阶段/门槛、时间预算；输出保存的完整日程与评价次数。

直接调用：`leo_budget_expired`, `leo_record_search_step`, `leo_resource_service`, `leo_service_is_better`。
调用入口：`leo_solve_original_search`。

## leo_original_neighbors

```matlab
function neighbors = leo_original_neighbors(problem,x,service,maxEvaluations,roundIndex,budget)
```

输入：完整可行日程及缓存服务、评价/时间预算；输出候选及其原始累计服务。
只重算受影响块内至多 L 位用户，价格代理不参与计分。

直接调用：`leo_budget_expired`, `leo_resource_service`。
调用入口：`leo_solve_original_search`, `test_leo_benchmark`。

## leo_original_upper_bound

```matlab
function bound = leo_original_upper_bound(data,cache,lambda,phase,s0)
```

接口标注：
输入：data/cache：完整模型和 UB1 缓存；lambda：非负价格；phase/s0。
输出：bound：原始公平或归一化吞吐有效上界、资源项与价格。

直接调用：`leo_price_weights`。
调用入口：`leo_run_price_phase`, `leo_solve_original_search`, `leo_solve_proxy_milp`, `test_leo_method`。

## leo_plot_benchmark

```matlab
function files = leo_plot_benchmark(report,directory)
```

输入：报告或 plotData、输出目录；输出：PNG/PDF/FIG 路径，另存数值输入。

直接调用：`leo_export_plot_data`, `leo_render_plot_specs`。
调用入口：用户直接调用 / 独立测试。

## leo_polish_group

```matlab
function x = leo_polish_group(qubo,x,maxMoves)
```

接口标注：
输入：qubo：固定二次目标；x：合法局部组；maxMoves：最大改进动作数。
输出：x：可行 add/drop/swap 改进后的组，代理收益不下降。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_resource_local`, `leo_solve_resource_sb`, `test_leo_method`。

## leo_precheck_positive_fairness

```matlab
function check = leo_precheck_positive_fairness(data)
```

接口标注：
输入：data：所有用户需求、正服务机会与硬约束。
输出：check：最大流值、见证日程、正公平可能性与不可服务用户。
无工具箱 Edmonds-Karp；仅判断正公平可服务性，不求 QoS 最优调度。
源->用户(1)->资源/码字(1)->资源(1)->汇(L)。不代表需求完全达标。

直接调用：`leo_evaluate_service`。
调用入口：`leo_form_problem`, `test_leo_problem`。

## leo_predict_orbit

```matlab
function o = leo_predict_orbit(p,r)
```

接口标注：
输入：p：轨道及地球参数；r：基本槽采样时刻。
输出：o：3×T 轨道位置 m、速度及 3×3×T 阵列姿态。
阵列 +z 指向地心，+x 为惯性轨道速度在切平面的方向，R 为右手系。

直接调用：基础 MATLAB 运算。
调用入口：`run_leo_sinr`。

## leo_prepare_design_service

```matlab
function d = leo_prepare_design_service(p,r,b,c,link)
```

接口标注：
输入：p/r/b/c/link：联合风险、资源、候选及固定链路系数。
输出：d：所有候选基本槽的风险/分位值、固定设计功率 W。
风险按有数据的基本槽计数，不能将固定块数 M 当作衰落事件数。

直接调用：`leo_rician_power_quantile`。
调用入口：`run_leo_sinr`, `test_leo_problem`。

## leo_prepare_upper_bounds

```matlab
function cache = leo_prepare_upper_bounds(data)
```

接口标注：
输入：data：完整物理域、用户—波束干扰及固定资源。
输出：cache：K×M×L 按组基数的原始服务上界 bit。
每基本槽分别放松；没有枚举用户组，没有使用 SB 内层值充当上界。
n=1 即无干扰单用户上界。所有物理可用波束均参与。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_original_search`, `leo_solve_proxy_milp`, `leo_solve_schedule`, `test_leo_method`。

## leo_price_weights

```matlab
function [weights,sAux] = leo_price_weights(data,lambda,phase,s0)
```

接口标注：
输入：data：需求及 Dref；lambda：K×1 非负价格；phase/s0：阶段和门槛。
输出：weights：K×1 服务权重（1/bit）；sAux：公平辅助解或固定门槛。

直接调用：基础 MATLAB 运算。
调用入口：`leo_original_upper_bound`, `leo_run_price_phase`, `test_leo_method`。

## leo_problem_nonlcon

```matlab
function [c,ceq] = leo_problem_nonlcon(z,data,stage,s0)
```

接口标注：
输入：z/data：优化向量与原模型；stage：1/2；s0：阶段 2 门槛。
输出：c/ceq：归一化非线性约束，c<=0；无额外等式。

直接调用：`leo_evaluate_service`。
调用入口：`leo_form_problem`, `leo_form_stage2`。

## leo_problem_objective

```matlab
function value = leo_problem_objective(z,data,stage)
```

接口标注：
输入：z：完整优化向量；data：原模型；stage：1 或 2。
输出：value：最小化形式的负公平/负归一化总服务。

直接调用：`leo_evaluate_service`。
调用入口：`leo_form_problem`, `leo_form_stage2`。

## leo_qubo_to_ising

```matlab
function ising = leo_qubo_to_ising(qubo)
```

接口标注：
输入：qubo：E=C+z'Qsym z 的对称二次编码。
输出：ising：J/h/constant，E=C'+h'sigma+sigma'J sigma/2。
J 对称、零对角；SB 的力须与此正号能量的梯度方向相反。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_resource_sb`, `test_leo_method`, `test_leo_plots`。

## leo_rate_and_derivatives

```matlab
function [rate,first,second] = leo_rate_and_derivatives(S,N,B,I)
```

接口标注：
输入：S/N/I：信号、噪声、干扰功率 W；B：带宽 Hz。
输出：rate/first/second：bit/s 及对 W 的一、二阶导数。
使用 I/N、S/N 归一化计算；支持标量或可广播数组，不以绝对 eps 判断零功率。

直接调用：基础 MATLAB 运算。
调用入口：`leo_build_service_surrogates`, `leo_chord_upper`, `leo_collect_plot_data`, `leo_tangent_lower`, `test_leo_surrogate`。

## leo_record_search_step

```matlab
function history = leo_record_search_step(history,service,iteration,seconds,evaluations)
```

输入：历史结构、原始 service、原生步号、求解开始后的秒数、累计评价数。
输出：追加一列的历史；第 0 步是该阶段开始时的可行值。

直接调用：基础 MATLAB 运算。
调用入口：`leo_original_greedy`, `leo_run_benchmark_method`, `leo_solve_original_search`。

## leo_recover_schedule

```matlab
function result = leo_recover_schedule(problem,x,phase,s0,options,roundIndex,budget)
```

接口标注：
输入：problem/x：原模型与起点；phase/s0：验收规则；options/roundIndex/budget。
输出：result：原始服务严格改善的完整日程、服务及动作计数。
每次仅重算受影响资源；拟接受时调用完整原始评价器复核，避免累计舍入误差。
阶段 2 的起点若不满足门槛，不用它冒充可行恢复点；保留日程仍单独恢复。

直接调用：`leo_budget_expired`, `leo_resource_service`, `leo_service_is_better`。
调用入口：`leo_run_price_phase`, `leo_solve_original_search`, `test_leo_method`。

## leo_render_plot_specs

```matlab
function files = leo_render_plot_specs(specs,directory)
```

输入：leo_build_plot_specs 输出、目录；输出：全部已保存文件的路径 cell。
兼容 R2018b；不依赖 Statistics Toolbox、tiledlayout 或 exportgraphics。

直接调用：基础 MATLAB 运算。
调用入口：`leo_plot_benchmark`, `run_leo_plot_results`。

## leo_repair_group

```matlab
function x = leo_repair_group(qubo,x)
```

接口标注：
输入：qubo：收益/冲突/容量信息；x：可能冲突的局部用户位。
输出：x：通过删除最小收益损失用户得到的合法组。

直接调用：基础 MATLAB 运算。
调用入口：`leo_solve_resource_local`, `leo_solve_resource_miqp`, `leo_solve_resource_sb`, `test_leo_method`。

## leo_resource_group_services

```matlab
function bits = leo_resource_group_services(data,m,groups)
```

接口标注：
输入：data：原始设计模型；m：块号；groups：K×G 合法组。
输出：bits：K×G 原始块服务 bit，支持批量穷举评价。
原始低分位设计系数，逐基本槽累计；缓存只消除重复运算，不近似速率。

直接调用：基础 MATLAB 运算。
调用入口：`leo_check_surrogate_groups`, `leo_exhaustive_search`, `leo_initial_schedules`, `test_leo_exhaustive`, `test_leo_method`。

## leo_resource_service

```matlab
function bits = leo_resource_service(data,m,group)
```

输入：固定模型 data、块号 m、K×1 二元 group。输出：K×1 原始设计服务 bit。
计算量 O(H_m L^2)，与批量组评价器完全相同的 R5-R6，非平均信道。

直接调用：基础 MATLAB 运算。
调用入口：`leo_original_greedy`, `leo_original_neighbors`, `leo_recover_schedule`, `test_leo_benchmark`。

## leo_rician_power_cdf

```matlab
function [cdfValue,cdfUpper] = leo_rician_power_cdf(z,kappa)
```

接口标注：
输入：z：非负归一化功率；kappa：线性 Rician 因子。
输出：cdfValue/cdfUpper：CDF 近似及带截断余项的上界。
2(1+kappa)Z ~ ncx2(2,2*kappa)。用 Poisson(kappa) 混合 Gamma(j+1,1)。
cdfUpper 加上截断尾质量和浮点裕量，用于保守数值求分位数。

直接调用：基础 MATLAB 运算。
调用入口：`leo_rician_power_quantile`, `test_leo_problem`。

## leo_rician_power_quantile

```matlab
function zeta = leo_rician_power_quantile(probability,kappa)
```

接口标注：
输入：probability：尾部概率；kappa：线性 Rician 因子。
输出：zeta：保守非负功率低分位，不含 dB 单位。
适用当前单个 kappa 的模型；不是蒙特卡洛近似。过小风险明确报错。

直接调用：`leo_rician_power_cdf`。
调用入口：`leo_prepare_design_service`, `test_leo_problem`。

## leo_run_benchmark_method

```matlab
function result = leo_run_benchmark_method(problem,proxy,provided,name,options)
```

输入：原问题、minimax 代理、提供日程、方法名、方法预算；输出方法的原始可行结果。

直接调用：`leo_record_search_step`, `leo_service_is_better`, `leo_solve_original_search`, `leo_solve_proxy_milp`, `leo_solve_schedule`。
调用入口：`leo_benchmark_case`。

## leo_run_price_phase

```matlab
function result = leo_run_price_phase(problem,proxy,cache,phase,start,options,budget)
```

接口标注：
输入：problem/proxy/cache：模型、固定代理、有效界；phase/start/options/budget。
输出：result：阶段日程、价格/迭代/工作量轨迹、上界、停止状态及首次内层 sbTrace。

直接调用：`leo_budget_expired`, `leo_build_service_surrogates`, `leo_evaluate_quadratic_service`, `leo_original_upper_bound`, `leo_price_weights`, `leo_recover_schedule`, `leo_service_is_better`, `leo_solve_resource`, `leo_update_prices`。
调用入口：`leo_solve_schedule`。

## leo_schedule_interference

```matlab
function I = leo_schedule_interference(data,x)
```

接口标注：
输入：data：设计信道；x：K×M 合法二元日程。
输出：I：K×T 干扰功率 W，含未选用户的反事实接收干扰。
未选用户的这个值可能超过条件 x_i=1 的 Imax，不能直接当作合法切点。

直接调用：`leo_evaluate_service`。
调用入口：`leo_build_service_surrogates`, `test_leo_surrogate`。

## leo_select_codebook

```matlab
function cb = leo_select_codebook(p,cb)
```

接口标注：
输入：p：目标码字数；cb：量化去重后的固定候选码本。
输出：cb：在用户产生前离线冻结的子码本。
固定扫描域上贪心增加达到 gmin 的验证点数；并列时最大化增益提升。
这只是离线字典子集规则，不声称最优覆盖；空洞由后续检查如实报告。

直接调用：`leo_array_response`。
调用入口：`leo_build_codebook`。

## leo_service_is_better

```matlab
function better = leo_service_is_better(candidate,incumbent,phase,s0)
```

接口标注：
输入：candidate/incumbent：原始服务；phase：fairness/throughput；s0：固定门槛。
输出：better：是否可替换保存日程；阶段 2 严格满足每用户门槛。

直接调用：基础 MATLAB 运算。
调用入口：`leo_initial_schedules`, `leo_original_greedy`, `leo_recover_schedule`, `leo_run_benchmark_method`, `leo_run_price_phase`, `leo_solve_original_search`, `leo_solve_proxy_milp`。

## leo_solve_original_search

```matlab
function result = leo_solve_original_search(problem,kind,options,provided)
```

输入：原问题、方法名、与 SB 共用初始化/时间选项、共同提供日程。
输出：原始可行日程；禁忌轨迹允许暂时退步，保存结果与阶段 2 门槛严格验收。

直接调用：`leo_budget_expired`, `leo_initial_schedules`, `leo_method_options`, `leo_original_greedy`, `leo_original_neighbors`, `leo_original_upper_bound`, `leo_prepare_upper_bounds`, `leo_record_search_step`, `leo_recover_schedule`, `leo_service_is_better`。
调用入口：`leo_run_benchmark_method`。

## leo_solve_proxy_milp

```matlab
function result = leo_solve_proxy_milp(problem,proxy,options,provided)
```

输入：原问题、初始代理、共用方法选项、共同提供日程；输出原始服务与独立有效界。
阶段 2 在阶段 1 保留日程处相切；MILP 最优只代表该固定代理最优。

直接调用：`leo_budget_expired`, `leo_build_service_surrogates`, `leo_call_milp`, `leo_form_proxy_milp`, `leo_initial_schedules`, `leo_method_options`, `leo_original_upper_bound`, `leo_prepare_upper_bounds`, `leo_service_is_better`。
调用入口：`leo_run_benchmark_method`。

## leo_solve_resource

```matlab
function result = leo_solve_resource(data,lower,m,weights,oldGroup,options,budget)
```

输入：模型、下界系数、块号、非负权重、旧组、选项、时间预算；输出合法组与代理分数。

直接调用：`leo_solve_resource_local`, `leo_solve_resource_miqp`, `leo_solve_resource_sb`。
调用入口：`leo_run_price_phase`。

## leo_solve_resource_local

```matlab
function result = leo_solve_resource_local(data,lower,m,weights,oldGroup,options,budget)
```

输入输出与 leo_solve_resource_sb 相同；保留旧组，允许空组，不调用 SB。

直接调用：`leo_budget_expired`, `leo_build_resource_qubo`, `leo_encode_group_bits`, `leo_polish_group`, `leo_repair_group`。
调用入口：`leo_solve_resource`。

## leo_solve_resource_miqp

```matlab
function result = leo_solve_resource_miqp(data,lower,m,weights,oldGroup,options,budget)
```

输入输出与 SB 内层一致；需要用户已安装并授权 Gurobi MATLAB 接口。
不存在求解器时明确报 unavailable，不以局部搜索冒充 MIQP。

直接调用：`leo_budget_expired`, `leo_build_resource_qubo`, `leo_encode_group_bits`, `leo_repair_group`。
调用入口：`leo_solve_resource`。

## leo_solve_resource_sb

```matlab
function result = leo_solve_resource_sb(data,lower,m,weights,oldGroup,options,budget)
```

接口标注：
输入：data/lower/m/weights：内层 L4；oldGroup：K×1；options/budget：搜索配置。
输出：result：合法 K×1 组、代理分数、SB 步数、实际修复数及 energyHistory；保留旧组。
同一组价格下保留旧组和空组，保证内层返回值不劣于这两个候选。

直接调用：`leo_ballistic_sb`, `leo_budget_expired`, `leo_build_resource_qubo`, `leo_encode_group_bits`, `leo_polish_group`, `leo_qubo_to_ising`, `leo_repair_group`。
调用入口：`leo_solve_resource`, `test_leo_method`。

## leo_solve_schedule

```matlab
function result = leo_solve_schedule(problem,proxy,options,initialSchedule)
```

接口标注：
输入：problem：原问题；proxy：可选已有代理；options：方法参数；initialSchedule：可选日程。
输出：result：两阶段日程、原始服务、严格公平门槛、有效差距与运行记录。
不调用穷举、不缩小物理候选域；每资源单独存储 QUBO/Ising。
options.enabled 仅控制主入口；直接调用本函数始终执行。

直接调用：`leo_budget_expired`, `leo_build_service_surrogates`, `leo_initial_schedules`, `leo_method_options`, `leo_prepare_upper_bounds`, `leo_run_price_phase`。
调用入口：`leo_run_benchmark_method`, `run_leo_sinr`, `test_leo_method`。

## leo_summarize_benchmark

```matlab
function summary = leo_summarize_benchmark(records,methods)
```

输入：逐次记录与方法列表；输出每方法一行；缺失结果不当作零或成功样本。

直接调用：基础 MATLAB 运算。
调用入口：`leo_benchmark_case`。

## leo_tangent_lower

```matlab
function line = leo_tangent_lower(S,N,B,referenceW)
```

接口标注：
输入：S/N：固定功率 W；B：Hz；referenceW：合法切点 W。
输出：line：alphaBps、omegaBpsPerW 与切点速率；ell=alpha-omega*I。

直接调用：`leo_rate_and_derivatives`。
调用入口：`leo_build_service_surrogates`, `test_leo_surrogate`。

## leo_update_prices

```matlab
function lambdaNext = leo_update_prices(lambda,lowerUserBits,q,sAux,step)
```

接口标注：
输入：lambda：价格；lowerUserBits：价格日程下界 bit；q：需求 bit；sAux/step。
输出：lambdaNext：非负投影后的新价格，负服务下界不截断。

直接调用：基础 MATLAB 运算。
调用入口：`leo_run_price_phase`, `test_leo_method`。

## leo_validate_parameters

```matlab
function p = leo_validate_parameters(p)
```

接口标注：
输入：p：原始参数结构。
输出：p：校验后参数，需求统一为 K×1，并更新所有派生量。

直接调用：`leo_exhaustive_options`, `leo_method_options`。
调用入口：`run_leo_sinr`, `test_leo_benchmark`, `test_leo_exhaustive`, `test_leo_method`, `test_leo_plots`, `test_leo_surrogate`。

## leo_write_struct_csv

```matlab
function leo_write_struct_csv(path,rows)
```

输入：输出路径、同字段结构体数组。输出：CSV 文件；NaN 表示不适用/未运行。

直接调用：基础 MATLAB 运算。
调用入口：`leo_export_benchmark`, `leo_export_plot_data`。

## run_leo_benchmarks

```matlab
function report = run_leo_benchmarks(caseOrParameters,overrides)
```

输入：'small'(默认 8用户/3块)、'default'(32用户/20块)或自定义参数；可选实验覆盖。
输出：报告、全部 CSV/MAT/JSON 及图形后端可用时的 18 图 PNG/PDF/FIG；不自动缩小参数。

直接调用：`leo_benchmark_case`, `leo_benchmark_options`, `leo_default_parameters`, `leo_export_benchmark`, `run_leo_plot_results`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## run_leo_exhaustive_demo

```matlab
function [model,comparison] = run_leo_exhaustive_demo(p)
```

接口标注：
输入：p：可选自定义参数；省略时 8 用户/3 块。
输出：model/comparison：原始完整穷举及轮换/预检见证对比。
保持 32 码本波束、最大 8 并发与原始设计速率。传入 p 时不改其规模。

直接调用：`leo_compare_schedules`, `leo_default_parameters`, `leo_exhaustive_options`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## run_leo_method_demo

```matlab
function [model,comparison] = run_leo_method_demo(p)
```

接口标注：
输入：p：可选自定义参数；省略时 8 用户/3 块并启用穷举。
输出：model/comparison：两阶段方法、后置穷举及同原始服务口径的比较。
仍为 32 波束、最多并发 8 人；用户传入 p 时绝不自动缩小规模。

直接调用：`leo_compare_schedules`, `leo_default_parameters`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## run_leo_plot_results

```matlab
function [files,plotData] = run_leo_plot_results(source,directory,render)
```

输入：benchmark.mat/plot_data.mat 路径或报告结构、输出目录；render 默认 true。
输出：图文件列表与数值 plotData；render=false 仅导出 CSV/MAT/JSON，适合无图形云环境。

直接调用：`leo_export_plot_data`, `leo_render_plot_specs`。
调用入口：`run_leo_benchmarks`, `test_leo_plots`。

## run_leo_sinr

```matlab
function model = run_leo_sinr(p)
```

接口标注：
输入：p：可选完整参数；默认 32 波束、8 并发、50 ms 固定块。
输出：model：物理模型、原问题、代理及启用时的 method/exhaustive 求解结果。
保留原入口名称以兼容前一版，无附加 MATLAB 工具箱依赖。
用法：model=run_leo_sinr(); 或修改 leo_default_parameters() 后传入。

直接调用：`leo_assign_beams`, `leo_build_codebook`, `leo_build_resources`, `leo_build_service_surrogates`, `leo_check_codebook_coverage`, `leo_compute_geometry`, `leo_compute_sinr`, `leo_default_parameters`, `leo_evaluate_service_bounds`, `leo_example_selection`, `leo_exhaustive_search`, `leo_form_problem`, `leo_generate_fading`, `leo_generate_users`, `leo_large_scale_channel`, `leo_link_coefficients`, `leo_predict_orbit`, `leo_prepare_design_service`, `leo_solve_schedule`, `leo_validate_parameters`。
调用入口：`run_leo_benchmarks`, `run_leo_exhaustive_demo`, `run_leo_method_demo`, `run_leo_surrogate_demo`, `test_leo_exhaustive`, `test_leo_model`, `test_leo_problem`, `test_leo_surrogate`。

## run_leo_surrogate_demo

```matlab
function [model,comparison] = run_leo_surrogate_demo()
```

接口标注：
输入：无；使用固定 8 用户/3 块穷举例。
输出：model/comparison：minimax 与当前点相切的服务夹逼/误差验证。

直接调用：`leo_build_service_surrogates`, `leo_check_surrogate_groups`, `leo_default_parameters`, `leo_evaluate_service_bounds`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## test_leo_benchmark

```matlab
function test_leo_benchmark()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。
无输入；全部断言通过时报告检查组数。小模型的精确参考来自独立位串枚举。

直接调用：`leo_benchmark_case`, `leo_benchmark_options`, `leo_build_resources`, `leo_build_service_surrogates`, `leo_call_milp`, `leo_default_parameters`, `leo_evaluate_quadratic_service`, `leo_form_problem`, `leo_form_proxy_milp`, `leo_method_options`, `leo_original_neighbors`, `leo_resource_service`, `leo_validate_parameters`。
调用入口：用户直接调用 / 独立测试。

## test_leo_exhaustive

```matlab
function test_leo_exhaustive()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。

直接调用：`leo_build_resources`, `leo_default_parameters`, `leo_enumerate_resource_groups`, `leo_exhaustive_options`, `leo_exhaustive_search`, `leo_form_problem`, `leo_resource_group_services`, `leo_validate_parameters`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## test_leo_method

```matlab
function test_leo_method()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。

直接调用：`leo_ballistic_sb`, `leo_build_resource_qubo`, `leo_build_resources`, `leo_build_service_surrogates`, `leo_default_parameters`, `leo_encode_group_bits`, `leo_enumerate_resource_groups`, `leo_evaluate_quadratic_service`, `leo_evaluate_service`, `leo_form_problem`, `leo_method_options`, `leo_original_upper_bound`, `leo_polish_group`, `leo_prepare_upper_bounds`, `leo_price_weights`, `leo_qubo_to_ising`, `leo_recover_schedule`, `leo_repair_group`, `leo_resource_group_services`, `leo_solve_resource_sb`, `leo_solve_schedule`, `leo_update_prices`, `leo_validate_parameters`。
调用入口：用户直接调用 / 独立测试。

## test_leo_model

```matlab
function test_leo_model()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。

直接调用：`leo_assign_beams`, `leo_build_resources`, `leo_compute_sinr`, `leo_default_parameters`, `leo_generate_fading`, `leo_geodetic_to_ecef`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## test_leo_plots

```matlab
function test_leo_plots()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。
输入：无；输出：通过检查组数；无需图形后端，不以作图外观代替数值验证。

直接调用：`leo_ballistic_sb`, `leo_benchmark_case`, `leo_benchmark_options`, `leo_build_plot_specs`, `leo_build_resource_qubo`, `leo_build_resources`, `leo_build_service_surrogates`, `leo_collect_plot_data`, `leo_default_parameters`, `leo_form_problem`, `leo_method_options`, `leo_qubo_to_ising`, `leo_validate_parameters`, `run_leo_plot_results`。
调用入口：用户直接调用 / 独立测试。

## test_leo_problem

```matlab
function test_leo_problem()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。

直接调用：`leo_build_codebook`, `leo_build_hard_constraints`, `leo_check_problem_point`, `leo_default_parameters`, `leo_evaluate_service`, `leo_precheck_positive_fairness`, `leo_prepare_design_service`, `leo_rician_power_cdf`, `leo_rician_power_quantile`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。

## test_leo_surrogate

```matlab
function test_leo_surrogate()
```

接口标注：
输入：无；构造独立数值基准及边界算例。
输出：无返回值；失败时抛出断言，成功时打印检查组数。

直接调用：`leo_build_resources`, `leo_build_service_surrogates`, `leo_check_surrogate_groups`, `leo_chord_upper`, `leo_default_parameters`, `leo_enumerate_resource_groups`, `leo_evaluate_service`, `leo_evaluate_service_bounds`, `leo_form_problem`, `leo_rate_and_derivatives`, `leo_schedule_interference`, `leo_tangent_lower`, `leo_validate_parameters`, `run_leo_sinr`。
调用入口：用户直接调用 / 独立测试。
