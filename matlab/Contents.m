% LEO 固定块 QoS：建模、两阶段拉格朗日 SB、原始穷举与统一实验。
% 完整公式/输入输出/调用关系见仓库 FUNCTION_GUIDE.md。
%
%   leo_array_response                 - [C1] 每列单位范数，p 索引优先变化，与码本一致。
%   leo_assemble_quadratic_service     - T5-T6：a_i*x_i - sum_{j~=i}b_ij*x_i*x_j。
%   leo_assign_beams                   - [G5-G6] 整资源同一码字最大化最差增益，只做物理过滤。
%   leo_ballistic_sb                   - 多轨迹 ballistic simulated bifurcation，无额外工具箱。
%   leo_benchmark_case                 - 第 13.3 节：同一物理样本上的多算法、多随机种子对比。
%   leo_benchmark_options              - 第 13.3 节统一实验设置：同输入、同种子、同端到端时间上限。
%   leo_budget_expired                 - 软时间预算；每个有限原子操作完成后检查。
%   leo_build_codebook                 - [C5-C8] 固定网格、有限相位、首阵元归零、稳定去重。
%   leo_build_hard_constraints         - O1：x(:) 按 MATLAB 列优先，资源内用户连续。
%   leo_build_plot_specs               - 生成完整图组的数值规格，MATLAB/Python 共用同一数据和口径。
%   leo_build_resource_qubo            - L4、Q1-Q4、M3：E=C+z'*Qsym*z，z=[用户位;松弛位]。
%   leo_build_resources                - [S2-S4] 连续不重叠固定资源、开销及槽内采样时刻。
%   leo_build_service_surrogates       - 第 7.1-7.5 节：切线下界、弦线上界、二次系数和误差。
%   leo_call_milp                      - MATLAB intlinprog / Octave GLPK 适配，不掩盖求解器缺失或超时。
%   leo_check_codebook_coverage        - 对固定扫描域抽样检查真实量化方向图。
%   leo_check_problem_point            - 对完整变量向量检查上下界、整数、线性和 QoS。
%   leo_check_surrogate_groups         - 枚举各资源全部合法组，检查每用户的服务夹逼和误差。
%   leo_chord_upper                    - T7-T10：单个速率函数在 [a,b] 上的弦上界与 minimax 切点。
%   leo_collect_plot_data              - 整理同口径绘图数据；不运行优化、不补造缺失迭代。
%   leo_compare_schedules              - 所有对照使用同一个问题和设计服务口径，不重新分配风险。
%   leo_compute_geometry               - [G3-G4] 斜距、仰角、阵列出射方向、正面扫描条件。
%   leo_compute_sinr                   - [P1,P3,P5-P6] 给定 KxM 合法二元选择矩阵的瞬时 SINR。
%   leo_default_parameters             - 参数集中入口；SI 单位，角度字段以 Deg 结尾。
%   leo_encode_group_bits              - 在修复用户组后重新编码松弛位，绝不沿用 SB 原始松弛位。
%   leo_enumerate_resource_groups      - 列出所有合法二元组，第一列是空组。
%   leo_evaluate_quadratic_service     - 评价单个二次服务表达式，不裁剪负下界。
%   leo_evaluate_service               - R5-R6、O3-O4：原始设计速率及跨块累计服务（bit）。
%   leo_evaluate_service_bounds        - 对同一合法完整日程比较下界、原始服务、上界。
%   leo_example_selection              - 仅演示合法选组：按用户编号轮换，同波束至多一人。
%   leo_exhaustive_options             - 穷举保护参数；超限明确返回，不缩小原问题或抽样。
%   leo_exhaustive_search              - 完整日程穷举，原始 O2/O4 字典序全局对照。
%   leo_exhaustive_size                - 合法组数 Gm 与完整日程数 prod(Gm)，不生成候选组。
%   leo_export_benchmark               - 导出实验 CSV/MAT 及全部可重画数值，包含迭代/价格/SB 能量日志。
%   leo_export_plot_data               - 导出绘图输入、迭代/时间/价格/能量 CSV 和跨渲染器 JSON。
%   leo_form_problem                   - 第 6 节 O1-O4：形成原始非线性混合整数问题，不求解。
%   leo_form_proxy_milp                - 第 13.3 节：直接线性化二次下界的完整周期 MILP。
%   leo_form_stage2                    - 2 O4：用给定可行日程的实际设计公平值形成第二阶段。
%   leo_generate_fading                - [C3-C4] 几何共同方向的归一化 Rician 瞬时样本。
%   leo_generate_users                 - 固定用户：先在球面帽均匀取点，再用 WGS-84 转 ECEF。
%   leo_geodetic_to_ecef               - [G1-G2] WGS-84 大地坐标与椭球向上法向，输出 3xK。
%   leo_initial_schedules              - 空/预检见证/用户提供/需求轮转/随机可行起点；不读取穷举。
%   leo_interference_limits            - T2-T3：条件 x_i=1 下，其他不同波束中最大的 L-1 项。
%   leo_large_scale_channel            - [C2,P4] 单阵元 beta、自由空间损耗、kB*Tsys*B。
%   leo_link_coefficients              - [P5] 与选择组无关的有用系数及用户-波束干扰系数。
%   leo_method_options                 - 配置 A：全物理候选域、两阶段拉格朗日 + ballistic SB。
%   leo_original_greedy                - 第 13.3 节：需求缺口优先，按原始服务选择最佳可加块。
%   leo_original_neighbors             - 第 13.3 节：生成原目标可行增删/替换及跨块交换邻域。
%   leo_original_upper_bound           - E4/E6 + UB1，有效原问题上界，独立于 SB 近似质量。
%   leo_plot_benchmark                 - 完整对比图入口：迭代、收敛、性能、资源及代理诊断共 18 图。
%   leo_polish_group                   - 可行组上的二次收益 add/drop/swap，严格单调、有限动作。
%   leo_precheck_positive_fairness     - O2/6.4：最大流检查每用户至少一次正服务。
%   leo_predict_orbit                  - 连续圆轨道 ECI -> ECEF；合成星历，不是 TLE/SGP4。
%   leo_prepare_design_service         - R1-R7：所有候选用户-基本槽的风险与设计系数。
%   leo_prepare_upper_bounds           - UB1：按组基数 n，取其他波束中最小 n-1 个干扰。
%   leo_price_weights                  - L3-L5、V3：阶段 1 的 s 辅助解与两阶段非负用户权重。
%   leo_problem_nonlcon                - 原始非线性累计 QoS，统一 c<=0；不含切线近似。
%   leo_problem_objective              - 最小化接口：阶段 1 为 -s，阶段 2 为 -sum(D)/Dref。
%   leo_qubo_to_ising                  - Q5：z=(1+sigma)/2，E=C'+h'*sigma+sigma'*J*sigma/2。
%   leo_rate_and_derivatives           - T1：设计速率及对干扰功率 I（W）的导数。
%   leo_record_search_step             - 记录原目标搜索的已保存可行值，不改变选择/验收规则。
%   leo_recover_schedule               - 12.2：整周期原始服务的有限 add/drop/replace/跨资源交换。
%   leo_render_plot_specs              - 基础 MATLAB 绘制全部规格，导出 PNG/PDF/可编辑 FIG。
%   leo_repair_group                   - 按最小二次收益损失删除冲突者，再删除超出容量者。
%   leo_resource_group_services        - R5-R6：一次计算所有合法组在一个资源的服务。
%   leo_resource_service               - 第 13.3 节：单个可行组只重算至多 L 个活跃用户。
%   leo_rician_power_cdf               - R2：归一化 Rician 功率的 CDF，无统计工具箱依赖。
%   leo_rician_power_quantile          - R2 低分位；二分返回 CDF 上界不超过 eps 的下端。
%   leo_run_benchmark_method           - 第 13.3 节实验分派；所有求解均只收到同一模型/初始化。
%   leo_run_price_phase                - 两阶段共用价格循环；内层、恢复、原始验收和有效上界分开。
%   leo_schedule_interference          - 合法完整日程的设计干扰；包含未选用户的反事实接收值。
%   leo_select_codebook                - 在用户生成前选定 NB 个码字，不依赖用户/日程/价格。
%   leo_service_is_better              - 原始设计服务验收；阶段 2 不容忍降低固定公平门槛。
%   leo_solve_original_search          - 第 13.3 节：原始速率的 greedy/exchange/tabu 两阶段基线。
%   leo_solve_proxy_milp               - 第 13.3 节：同一切线代理的直接 MILP 两阶段对照。
%   leo_solve_resource                 - 第 13.3 节：相同 L4 内层目标的 SB/局部搜索/MIQP 调度。
%   leo_solve_resource_local           - 第 13.3 节：同一二次代理的多起点可行 add/drop/swap。
%   leo_solve_resource_miqp            - 第 13.3 节：Gurobi 求解相同 L4 的受约束二元 MIQP。
%   leo_solve_resource_sb              - 资源 QUBO -> Ising -> 多轨迹 SB -> 修复 -> 代理计分。
%   leo_solve_schedule                 - 第 8-12 节配置 A，原始设计模型上的两阶段启发式搜索。
%   leo_summarize_benchmark            - 第 13.3 节：分别统计成功/缺失/失败、典型值及最好完整运行。
%   leo_tangent_lower                  - T4：ell(I)=alpha-omega*I，保留可能为负的切线值。
%   leo_update_prices                  - L6/V4：使用价格子问题日程的下界服务，而非恢复/原始服务。
%   leo_validate_parameters            - 检查物理约束，并统一更新所有派生参数。
%   leo_write_struct_csv               - 导出标量结构体表，UTF-8；字符串引号/逗号正确转义。
%   run_leo_benchmarks                 - 文档第 13.3 节统一对比主入口，固定 32 波束/最多 8 人。
%   run_leo_exhaustive_demo            - 可实际完成的穷举对照：8 用户，3 个 50 ms 资源。
%   run_leo_method_demo                - 默认 8 用户/3 个固定块，与原问题完整穷举对照。
%   run_leo_plot_results               - 从已保存结果重画全部图，无需再次运行优化算法。
%   run_leo_sinr                       - 主入口：建模、代理；可选两阶段拉格朗日 SB 和原始问题穷举。
%   run_leo_surrogate_demo             - 在原 8 用户/3 块穷举小例上验证切线与弦线。
%   test_leo_benchmark                 - 对比可信性：原始增量服务、零切点、MILP 等价性、预算和共同初始化。
%   test_leo_exhaustive                - 以独立全二元位枚举核对穷举算法，不使用同一组生成器。
%   test_leo_method                    - 精确位串/组枚举验证能量、硬约束、有效界及两阶段原始服务验收。
%   test_leo_model                     - 无附加工具箱测试，包含独立复矩阵接收功率核对。
%   test_leo_plots                     - 验证图表计数、真实时间、有效界、SB 能量、缺失值和导出接口。
%   test_leo_problem                   - 原始问题形成检查；独立 CDF 数值、直接接收功率、枚举硬约束。
%   test_leo_surrogate                 - 凸性、minimax、硬约束干扰区间、二次系数、参考点和边界检查。
