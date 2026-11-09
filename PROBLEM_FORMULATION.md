# 固定时间块下的原始问题形成

**V5 主入口更新：** 当前目标与多级证书以 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md) 为准；下文保留基础/历史推导与接口背景。主入口使用32用户、8×8阵列、32波束、每块最多7人，统一全员QoS门槛；旧入口的参数与降低门槛行为不能混作V5实验。

本实现沿用方案第 1–4 节物理模型。2026-11-07 默认可靠性模型改为周期累计 Chernoff 证书；完整推导见 [PERIODIC_QOS.md](PERIODIC_QOS.md)。
函数均已接入主函数 `run_leo_sinr`（为兼容旧版保留此名称）。
本文说明原始问题的形成接口；另有可选完整日程穷举求解器，见 [EXHAUSTIVE_BASELINE.md](EXHAUSTIVE_BASELINE.md)。
问题形成函数本身不求解；新增切线/弦线模块单独保存于 `model.surrogate`，见 [TANGENT_CHORD.md](TANGENT_CHORD.md)。
原始 O2/O4 回调仍计算原式，没有被代理替换。

## 时间、变量和硬约束

默认 K=32，T=100 个 10 ms 基本槽；每 H=5 槽合为一个固定调度资源，M=20。
最后不足 H 槽时保留尾部短块。资源内用户选择和码字不变，槽间几何/信道系数仍可变化。

`x` 为 K×M 二元矩阵，按 MATLAB 列优先排列：`index(i,m)=i+(m-1)*K`。
没有额外的逐槽选择变量；槽 t 由 `slotToResource(t)` 指向对应的 x 列。
单资源硬约束 O1：

\[
x_{im}\in\{0,1\},\quad x_{im}\le v_{im},\quad
\sum_i x_{im}\le8,\quad
\sum_{i:v_{im}=1,\ b_{im}=b}x_{im}\le1.
\]

`leo_build_hard_constraints` 输出稀疏 A、b 和变量上下界。
不可用变量上界固定为 0，用户需求及 QoS 约束保留。
每流 p0=10 W，人数限制蕴含总平均功率≤80 W。
32 是固定字典的大小；每资源至多使用 8 个不同波束，不强制每次满载。

## 默认：周期累计可靠性证书

`p.statistics.serviceModel='periodic_chernoff'`：对每用户分配风险 ε_i=0.05/K，
取好槽阈值 z0=0.25，依靠同一用户槽间独立计算累计服务的 Chernoff 保证。
在阈值信道服务 b_it 上乘固定弦斜率 ρ_i，得到 A_i=Σ_t ρ_i b_it；
每周期扣除一次余量 m_i=log(1/ε_i)/θ_i，保证服务为 G_i=[A_i−m_i]_+。
有 P(∀i: D_i^act≥G_i)≥0.95，详见 [推导与上界公式](PERIODIC_QOS.md)。

下文 O2/O4 中 D_i 在新模式下统一指 G_i；旧模式下指逐槽低分位服务的和。

## 旧模式：风险预算和 Rician 低分位（slot_union）

仅当 `serviceModel='slot_union'` 时采用 R1–R7 的**全部候选位置同时保证**口径，未采用可选 R8。
令 E 为满足整资源准入且净数据时间正的所有 `(i,t)`，先于日程选择固定：

\[
\varepsilon_{it}=\varepsilon_{\mathrm{tot}}/|E|\quad((i,t)\in E),
\qquad\varepsilon_{\mathrm{tot}}=0.05.
\]

固定块中每个基本槽仍有各自衰落事件，不能用 M 替换事件数中的 T。
默认 |E|=3200，每候选基本槽风险 0.000015625。
无候选事件时风险及设计系数为零，报告零公平，不生成伪分位数。

R2：

\[
2(1+\kappa)Z\sim\chi'^2_2(2\kappa),\qquad\zeta=F_Z^{-1}(\varepsilon).
\]

`leo_rician_power_cdf` 使用 Poisson 混合：

\[
F_Z(z)=\sum_{j=0}^{\infty}e^{-\kappa}\frac{\kappa^j}{j!}
P(j+1,(1+\kappa)z),
\]

P 是正则化下不完全 Gamma 函数。代码调用基础函数 `gammainc`，不依赖 `ncx2inv`。
`leo_rician_power_quantile` 二分返回下端点，加截断尾质量与浮点裕量，避免分位数向上偏。
这是双精度保守数值处理，不是任意精度或区间算术证明；风险过小或 kappa>10000 时明确报错。
测试用独立 SciPy 非中心卡方分位数作基准；旧模式 zeta≈0.015963795。

所述模型下联合事件概率至少 0.95，不要求用户/槽之间独立。
保证针对模型内可达服务能力，不等同于协议实际成功交付概率。
`leo_prepare_design_service` 不接收瞬时 `fading.g/Z/h`，避免用未来样本构造问题。

## 逐槽服务与周期汇总

旧模式 R4 用同一接收用户的 zeta；新模式将 zeta 替换为固定阈值 z0，随后还需弦斜率与周期余量。两者均用接收用户的同一系数同时缩放有用和干扰系数：

\[
S_{it}=\zeta_{it}\widetilde S_{it},\quad
c_{ij,t}=\zeta_{it}\widetilde c_{ij,t},\quad
I_{it}(x_m)=\sum_{j\ne i}c_{ij,t}x_{jm}.
\]

R5–R6：

\[
r_{it}=B\log_2\!\left(1+\frac{S_{it}}{N_{it}+I_{it}(x_m)}\right),\quad
D_{im}=\sum_{t\in\mathcal I_m}d_t x_{im}r_{it},\quad D_i=\sum_mD_{im}.
\]

上式的 D_im、D_i 是旧模式汇总。新模式保存 A_im=ρ_i Σ_t d_t x_im r_it，跨块累加后才计算 G_i=[Σ_m A_im−m_i]_+。
先逐槽计算速率，不用平均信道替代各槽速率。
速率单位 bit/s、时间单位 s、服务单位 bit；完整块有效数据时间 44.8 ms。
q_i 是需求目标，不将服务裁剪到 q_i。

```matlab
x = model.problem.precheck.witness;
D = model.problem.evaluate(x);
D.resourceBits                      % K x M；新模式为扣余量前的 A_im
D.userBits                          % K x 1；新模式为 G_i，旧模式为 D_i
D.totalBits                         % 全用户周期保证总 bit，不是实际平均吞吐
D.fairness                          % min(1,min(D_i/q_i))
```

瞬时 `model.sinr.gamma` 与设计 SINR 使用不同增益，不能把瞬时服务当作 O2/O4 的目标。
`problem.evaluate` 默认拒绝不可行或非二元日程；求解回调内部允许 [0,1] 上的代数延拓，
但不将分数选择解释为合法调度，整数约束由 `intcon` 给出。

## 第一阶段：公平优先 O2

\[
\max_{x,s}s,\qquad D_i(x)/q_i\ge s\ (\forall i),\quad
0\le s\le1,\quad x_m\in\mathcal X_m.
\]

`z=[x(:);s]`，默认 640 个二元 x 与 1 个连续 s。
接口用最小化约定：`objective(z)=-s`，`nonlcon(z)` 返回 `c=s-D./q<=0` 及空 `ceq`。

```matlab
PF = model.problem.stage1;
x = model.problem.precheck.witness;
D = model.problem.evaluate(x);
z = [double(x(:));D.fairness];
value = PF.objective(z);
[c,ceq] = PF.nonlcon(z);
report = leo_check_problem_point(PF,z,1e-9);
```

`A/b` 是人数与同波束线性约束，`lb/ub` 包含可见性和 s∈[0,1]，
`intcon` 仅包含 x 的索引，`x0` 是空日程与 s=0。
这是含原始干扰速率的非线性混合整数问题，不能直接交给仅接受线性模型的 `intlinprog`。
默认建模入口不启动搜索；`p.exhaustive.enabled=true` 时追加完整日程穷举对照。

## 第二阶段：保持已达到公平并提高吞吐 O4

给定外部可行日程 x0，计算其实际设计公平 s0，再形成：

\[
\max_x\frac{\sum_iD_i(x)}{D_{\mathrm{ref}}},\qquad
D_i(x)/q_i\ge s_0\ (\forall i),\quad x_m\in\mathcal X_m.
\]

默认 D_ref=sum(q_i)，固定且与 x 无关。
目标函数返回负的归一化吞吐，非线性约束返回 `s0-D./q<=0`。

```matlab
x0 = model.problem.precheck.witness; % 或未来阶段 1 返回的可行日程
PV = model.problem.makeStage2(x0);
PV.s0
PV.objective(PV.x0)
leo_check_problem_point(PV,PV.x0,1e-9)
```

主函数中 `stage2Example` 基于最大流预检见证构造；新模式见证可能只有零保证公平，旧模式约为 0.0338015。
它不是公平最优值；只有未来第一阶段证明最优，才能称为全局字典序第二阶段。
轮换演示 `xExample`、预检见证和 `stage2Example.x0` 都不是优化结果。

## 正公平预检

`leo_precheck_positive_fairness` 建立“源→用户→资源/码字→资源→汇”的整数容量网络。
最大流=K 当且仅当每位用户至少能被合法分配一次正阈值服务机会；新模式尚需跨槽累计抵消风险余量。
K≤LM 仅是必要条件，码字互斥和可用性也会造成不足。

返回 `maxFlow`、`canHavePositiveFairness`、`forcedZeroFairness`、
`neverServiceableUsers`、`unmatchedUsersInWitness` 和可行 `witness`。
默认最大流 32/32。新模式中成功只证明传输机会，不能单独证明正保证公平或全部 QoS 可行。
`allUsersHaveOpportunity` 记录流是否满；`canHavePositiveFairness` 在新模式中仅当见证已经取得正保证公平时为 true（false 不证明不可能）。
某用户全周期不可服务时仍保留其 QoS 约束并报告零公平。

## 保存与恢复

不把含匿名函数句柄的 `problem` 写入跨 MATLAB/Octave 的 MAT 文件：

```matlab
snapshot = rmfield(model,'problem');
save('leo_problem_snapshot.mat','snapshot','-v7');
loaded = load('leo_problem_snapshot.mat');
model = loaded.snapshot;
model.problem = leo_form_problem(model.parameters,model.resources,model.beams,model.design);
model.problem.stage2Example = model.problem.makeStage2(model.problem.precheck.witness);
```

恢复需要函数仍在路径中；此步骤只重建回调，不执行优化。
