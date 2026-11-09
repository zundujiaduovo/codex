# 两阶段拉格朗日与 SB 实现

**V5 主入口更新：** 当前目标与多级证书以 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md) 为准；下文保留基础/历史推导与接口背景。主入口使用32用户、8×8阵列、32波束、每块最多7人，统一全员QoS门槛；旧入口的参数与降低门槛行为不能混作V5实验。

默认可靠性口径为 [周期累计证书](PERIODIC_QOS.md)。下文 D_i 表示保证服务 G_i；
旧 `slot_union` 模式退化为原逐槽服务。总服务目标是保证总服务，不应当作真实平均吞吐。

## 运行入口

```matlab
addpath('matlab');
p = leo_default_parameters();
p.method.enabled = true;
model = run_leo_sinr(p);
result = model.method;
x = result.x;                           % K×M，每列为一个固定时间块
result.service.userBits                 % 每用户原始设计服务，bit
result.service.demandRatio              % D_i/q_i，未封顶
result.service.fairness                 % min(1,min(D_i/q_i))
result.fairnessGap                      % 有效原始公平上界减可行值
result.throughputGapBits                % 固定 s0 下有效吞吐差距，bit
```

默认模型是 32 用户、32 波束、8 并发、20 个 50 ms 块。`run_leo_method_demo()` 为 8 用户/3 块，
先求解方法，再运行穷举；穷举日程没有传给初始化。`problem.solved=false` 表示原始问题模板本身没有求解状态，
实际求解结果位于 `model.method` 或 `model.exhaustive`。

## 公式与函数

| 环节 | 数学含义 | 函数 |
|---|---|---|
| 原始服务 R5–R6 | 阈值 Shannon 服务乘 ρ_i，周期累计扣 m_i 后截零 | `leo_evaluate_service` |
| 下界 T5–T6 | Dlow_i=Σm[a_im x_im−Σj b_ijm x_im x_jm]−m_i | `leo_build_service_surrogates` |
| 价格 L3–L6 | w_i=λ_i/q_i；λ←[λ+η(sAux−Dlow_i/q_i)]_+ | `leo_price_weights`, `leo_update_prices` |
| 阶段 2 V3–V4 | w_i=1/Dref+λ_i/q_i；sAux=s0 | 同上 |
| 资源收益 L4 | Aᵀx−Σi<j B_ij x_i x_j，B_ij=w_i b_ij+w_j b_ji | `leo_build_resource_qubo` |
| 硬约束 Q1–Q4 | 容量平方罚+同波束成对冲突罚；罚权>Amax | 同上 |
| Ising Q5 | z=(1+σ)/2；E=C′+hᵀσ+σᵀJσ/2 | `leo_qubo_to_ising` |
| SB | 辛 Euler、线性泵浦、多轨迹、非弹性边界 | `leo_ballistic_sb` |
| 修复与恢复 | 资源硬约束修复；完整周期原始服务增删/交换 | `leo_repair_group`, `leo_recover_schedule` |
| 原始上界 E4/E6、UB1 | 按组大小使用最小可能干扰，再按波束取加权上界 | `leo_prepare_upper_bounds`, `leo_original_upper_bound` |

新模式 a/b 系数和误差预算均乘 ρ_i；m_i 只扣一次。代理价格使用有符号 Dlow，最终评分使用 G=[A−m]_+。
余量常数不进入资源 QUBO，但进入价格反馈、MILP 右端和有效上界，具体式见 [PERIODIC_QOS.md 第 4 节](PERIODIC_QOS.md)。

`leo_solve_schedule` 构造共同初始化、上界缓存并调用两次 `leo_run_price_phase`。
第一阶段按“原始公平优先、原始总服务次优”保存日程。第二阶段固定第一阶段实际公平 `s0`，
在保留日程处重新相切；只有所有用户满足原始 `D_i/q_i>=s0` 且总服务增加才替换。
价格更新始终使用价格子问题日程的下界服务，恢复日程只用于原始评分和保存。

## QUBO、SB 的数值约定

`Qsym` 表示 `C+z'*Qsym*z`。`Qupper` 上三角非对角项是 `Qsym` 的两倍。
Ising 的 `J` 是零对角对称矩阵，能量的二次项含 `1/2`；SB 的力取该正号能量的负梯度。
所有 J 和 h 按同一正尺度归一化。罚权每轮随权重重算，默认 `1.1*Amax`；Amax=0 时使用正罚权 1。
若可用波束数不超过 L，同波束约束已蕴含容量约束，删除容量罚和松弛位。
SB 输出仍必须修复；松弛位在修复后重新编码。保留旧组和空组，避免近似内层降低旧组的同价格代理分数。

## 主要参数

集中入口为 `leo_method_options`。这些是可调演示参数，不是论文复现值或收敛保证。

| 参数 | 默认值 | 含义 |
|---|---:|---|
| fairnessRounds / throughputRounds | 24 / 12 | 两阶段价格迭代上限 |
| maxSeconds | 60 | 求解软预算，含初始化、修复、复核和上界 |
| fairnessBudgetFraction | 0.7 | 第一阶段的累计预算上限，余下时间可用于阶段 2 |
| fairnessStep / throughputStep | 0.25 / 0.15 | η_k=η_0/k^0.6 |
| refreshEvery | 6 | 每 6 轮在当前保存日程处更新切点；0 为阶段内固定 |
| sbSteps / sbTrajectories | 250 / 16 | 每资源 SB 积分步数与轨迹数 |
| sbTimeStep / sbCoupling | 0.15 / 1 | 无量纲积分步长与耦合强度 |
| recoveryEvaluations / recoveryPasses | 160 / 4 | 每轮每个恢复起点的动作评价预算 |
| innerSolver | sb | 可选 local / miqp，保持其他价格与验收机制 |

主模型的物理建模时间另外记录于 `model.timings`。对比入口将共同预处理时间加回每种方法，
并从同一总预算中扣除。预算在有限操作间检查；单次矩阵装配、原始复核或外部求解器返回可能造成超额，
实验 CSV 明确记录 `budgetOverrunSeconds`，不把软预算描述为硬实时保证。

## 结果与最优性

`result.stage1/2.history` 保存价格、价格日程、下界服务、保存日程成绩、有效上界、SB 工作量和时间。
`proxyEpochFairnessErrorBounds` 记录换切点后的 E3 误差界。超时且未构造代理时相关误差为 NaN。
`fairnessGap` 是对原始公平目标的有效界差；`throughputGapBits` 只针对已取得的固定门槛 s0。
SB 停滞、迭代结束和高质量日程都不单独证明最优，`optimal` 因而保持 false；小规模可额外用穷举验证。
