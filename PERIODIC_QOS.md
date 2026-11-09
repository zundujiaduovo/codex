# 周期累计 QoS：公式、实现与实验口径（2026-11-07）

**V5 主入口更新：** 当前目标与多级证书以 [FULL_QOS_MODEL.md](FULL_QOS_MODEL.md) 为准；下文保留基础/历史推导与接口背景。主入口使用32用户、8×8阵列、32波束、每块最多7人，统一全员QoS门槛；旧入口的参数与降低门槛行为不能混作V5实验。

默认可靠性模型改为 `periodic_chernoff`。物理参数、固定功率、码本、调度块、用户数和 5% 联合风险预算保持不变。
旧的 `slot_union` 模型仍可运行，用于保守对照和历史结果复现。
这次改变的是可靠性约束的充分条件，不是提高发射功率，也不是把平均信道速率当作保证。

## 1. 真正要保证的事件

日程只依赖几何和统计 CSI，在未来衰落实现之前固定。令真实周期服务为

\[
D_i^{\rm act}(x,Z)=\sum_t d_t x_{i,m(t)}B\log_2\left(1+
\frac{Z_{it}\widetilde S_{it}}{N_{it}+Z_{it}\widetilde I_{it}(x)}\right).
\]

目标是为这个**固定日程**提供服务向量 \(G(x)\)，使

\[
\Pr\{D_i^{\rm act}(x,Z)\ge G_i(x),\ \forall i\}\ge1-\varepsilon_{\rm tot},
\qquad\varepsilon_{\rm tot}=0.05.
\]

每用户的基本槽衰落独立，符合当前 `leo_generate_fading` 的生成方式；不要求用户之间独立。
若实际衰落在 10 ms 槽间显著相关，应重建相关模型或使用 `slot_union`。
`independentSlots=false` 时，新模式明确拒绝运行。数学保证针对模型内可达服务量，不含未建模的编码、重传或协议损失。

旧模式要求全部 3200 个候选用户—槽事件同时成立，单事件风险为 0.05/3200，产生约 0.01596 的功率分位数。
新模式允许部分时隙深衰落，只约束周期累计量；两种模式的确定性最优值/上界不能直接当成同一个问题的数值比较。

## 2. 从好/坏槽到 Chernoff 证书

预先固定 \(z_0=0.25\)，令 \(p\ge F_Z(z_0)\) 为保守 CDF 上界。Rician 因子 10 dB 时 \(p\approx0.011262716\)。
同一接收用户的信号与所有干扰共同乘以 \(Z\)，SINR 随 \(Z\) 单调增加。定义

\[
b_{it}(x)=d_t x_{i,m(t)}B\log_2\left(1+
\frac{z_0\widetilde S_{it}}{N_{it}+z_0\widetilde I_{it}(x)}\right).
\]

因此 \(D_i^{\rm act}\ge\sum_t b_{it}U_{it}\)，其中 \(U_{it}=1\{Z_{it}\ge z_0\}\)。坏槽的实际非负服务被忽略，这是保守来源之一。
为每用户分配 \(\varepsilon_i=\varepsilon_{\rm tot}/K\)。任取预先固定的 \(\theta_i>0\)，槽间独立给出

\[
\Pr\{D_i^{\rm act}<d\}\le
\exp\left(\theta_i d+\sum_t\log[p+(1-p)e^{-\theta_i b_{it}}]\right).
\]

将右端截到 1 得到合法概率上界；目标 \(d=0\) 的失败概率精确为零。
`leo_certify_period_qos` 直接计算这个式子，用于独立检查最终日程。

## 3. 保留可加服务与二次代理结构

直接优化上面的对数乘积会改变现有 QUBO 结构。采用可证明的弦下界：

\[
h_i(b)=-\theta_i^{-1}\log[p+(1-p)e^{-\theta_i b}],\qquad
h_i(0)=0,\quad h_i''(b)\le0.
\]

用所有可用槽的无干扰服务计算固定上限

\[
\bar b_i=\max_{t\in E_i}d_tB\log_2(1+z_0\widetilde S_{it}/N_{it}),
\quad\theta_i=\tau/\bar b_i,\quad\tau=2.5.
\]

代码给 \(\bar b_i\) 加 1e-12 相对向上余量，给下述斜率加相对向下余量。
对 \(0\le b\le\bar b_i\)，凹性给出

\[
h_i(b)\ge\rho_i b,\qquad
\rho_i=\frac{-\log[p+(1-p)e^{-\tau}]}{\tau}.
\]

默认 \(\rho_i\approx0.9526\)。定义

\[
A_{im}(x_m)=\rho_i\sum_{t\in\mathcal I_m}b_{it}(x),\quad
A_i=\sum_m A_{im},\quad
m_i=\frac{\log(1/\varepsilon_i)}{\theta_i},\quad
\boxed{G_i(x)=[A_i(x)-m_i]_+}.
\]

若 \(G_i>0\)，代入 Chernoff 上界得到 \(\Pr\{D_i^{\rm act}<G_i\}\le\varepsilon_i\)；若 \(G_i=0\)，结论显然成立。
再对用户取联合界，得到第 1 节的 95% 联合保证。
没有正服务机会的用户直接取 \(G_i=0\)，避免除零。`totalBits` 是 \(\sum_iG_i\)，不截到需求 \(q_i\)。

余量 \(m_i\) **每周期每用户只扣一次**。不能每块扣一次，不能逐块把负值截零后再相加。
`resourceBits` 存可加的 \(A_{im}\)，`effectiveUserBits` 存 \(A_i\)，`signedUserBits` 存 \(A_i-m_i\)，`userBits` 存 \(G_i\)。
双精度数值采取保守裕量；不是区间算术认证。

## 4. 两阶段目标与代码同步

\[
\mathrm{P_F}:\quad\max_{x,\,0\le s\le1}s
\quad\text{s.t.}\quad G_i(x)\ge sq_i,\quad x_m\in\mathcal X_m;
\]

\[
\mathrm{P_V}:\quad\max_x\sum_iG_i(x)/D_{\rm ref}
\quad\text{s.t.}\quad G_i(x)\ge s_0q_i,\quad x_m\in\mathcal X_m.
\]

当 \(s_0>0\)，所有可行用户都有正保证服务，因此阶段 2 的目标为 \((\sum_iA_i-\sum_i m_i)/D_{\rm ref}\)。
速率切线/弦线的资源系数和误差预算都乘 \(\rho_i\)。周期二次下界为

\[
\underline G_i=\sum_m\left(a_{im}x_{im}-\sum_{j\ne i}b_{ijm}x_{im}x_{jm}\right)-m_i.
\]

价格更新使用这个**未截断的有符号下界**：

\[
\lambda_i^{k+1}=[\lambda_i^k+\eta_k(s_{\rm aux}-\underline G_i/q_i)]_+.
\]

\(m_i\) 是与日程无关的常数，不改变资源 QUBO 的最优组；但必须出现在价格反馈、MILP 的 QoS 右端和有效上界中。
MILP 要求 \(\underline A_i\ge m_i+sq_i\)；当 \(s=0\) 时这是原问题的更强充分约束，可能没有可行解。
原问题的空日程仍是零公平可行解。代理当前点相切核对的是 \(A_i-m_i\)，不是截断后的零值。
最终验收和所有直接搜索均使用 \(G\)；恢复、禁忌搜索、完整穷举也统一使用同一评价器。

令 \(H(w)\) 为 UB1 对 \(\max_x\sum_iw_iA_i\) 的有效上界。新版上界为

\[
U_F=\max\{0,\min\{1,[1-\sum_i\lambda_i]_++H(\lambda/q)-\sum_i\lambda_i m_i/q_i\}\};
\]

对 \(s_0>0\)：

\[
U_V=H(1/D_{\rm ref}+\lambda/q)-s_0\sum_i\lambda_i
-\sum_i\lambda_i m_i/q_i-\sum_i m_i/D_{\rm ref}.
\]

若 \(s_0=0\)，使用安全但较松的 \(U_V=H(1/D_{\rm ref}+\lambda/q)\)。此时不能从总和错误扣除所有用户的余量，因为部分用户的保证服务已截为零。
这些界仅针对**当前确定性证书模型**，不是随机物理系统的容量上界。

最大流失败仍能证明公平为零；最大流成功只证明每用户有一次传输机会，未证明足以抵消周期风险余量。

## 5. 指标、复现和实验设计

| 指标 | 定义与用途 |
|---|---|
| 保证公平 | \(\min(1,\min_iG_i/q_i)\)，衡量最差用户 |
| 保证 QoS 达标率 | \(K^{-1}\sum_i1\{G_i\ge q_i\}\)，不是可靠性概率 |
| 平均完成比例 | \(K^{-1}\sum_i\min(1,G_i/q_i)\)，不能替代达标人数 |
| 保证总服务 | \(\sum_iG_i\) bit；除整个周期秒数才是 bit/s |
| 标称总服务 | 原始链路取 \(Z=1\)，既非期望值也非可靠性保证 |
| 衰落仿真吞吐 | 固定日程、独立新样本上的真实服务均值；附 QoS 联合通过率 |

```matlab
addpath('matlab');
p = leo_default_parameters();               % periodic_chernoff, z0=.25, tau=2.5
p.method.enabled = true;
model = run_leo_sinr(p);
certificate = leo_certify_period_qos(model.problem.data,model.method.x);
nominal = leo_evaluate_nominal_service(model.problem.data,model.method.x);
mc = leo_sample_period_service(model.problem.data,model.method.x,10,2000,20261108);

p.statistics.serviceModel = 'slot_union';    % 复现旧可靠性模型
legacy = run_leo_sinr(p);
test_leo_periodic();
reports = run_leo_periodic_sweep('results/periodic_qos');
```

负载扫描预先固定为每用户 1、2、4 Mbit，物理样本和算法种子一致，每方法 12 秒端到端软预算、3 个种子。
1 Mbit 用于验证低负载能否全员达标；2、4 Mbit 用于观察紧张/超载情况下公平与吞吐权衡。
每个负载的首个算法种子另用 2000 个独立衰落周期验证；同一批衰落用于各方法，验证样本不参与优化。
即使所有算法都提高，也只能说明模型保守性得到缓解；SB 的优势必须由同预算、多种子及 SB/局部搜索消融对比支持。

补充预算检查（固定 2 Mbit，不据结果重新选物理样本）：

```matlab
p = leo_default_parameters(); p.system.qosTargetBits = 2e6;
o = struct('seeds',20261105,'budgetSeconds',60,'exhaustive',false,'makePlots',false);
o.methods = {'original_tabu','price_sb','price_local'};
o.outputDirectory = 'results/periodic_qos/load_2_Mbit_60s';
report = run_leo_benchmarks(p,o);
```

默认 32 用户使用 `leo_reference_users_32` 冻结坐标，以保证 MATLAB/Octave 的覆盖几何一致。需要随机新位置时设置 `p.users.layout='random_cap'`，并检查 `model.problem.precheck.maxFlow`。快速生成一张可见结果图可运行 `run_leo_quickstart()`。
