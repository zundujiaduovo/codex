# 全用户 QoS 下的保证总服务上界

`run_leo_comparison` 会自动计算 `report.theory` 并保存 `theoretical_bound.png`、`theoretical_bound.fig`、`theoretical_bound_summary.csv`、`theoretical_bound_by_run.csv` 和 `theoretical_bound.mat`。

全部结果使用当前一次实验的固定物理样本、链路、资源及周期可靠性参数。统一比较的问题为：在每个用户的保证服务 `G_i >= q_i` 下，最大化 `sum(G_i)`。不满足全用户 QoS 的方法显示 N/A，不与此门槛下的最优值直接比较。不同随机种子的物理样本相同；图中每个方法取达标的最好一次，全部逐次结果见 CSV。

全用户目标严格为正时，`G_i=[A_i-m_i]_+ >= q_i` 等价于 `A_i >= q_i+m_i`，目标为 `sum(A_i)-sum(m_i)`。其中 `A_i` 跨块可加，`m_i` 是周期风险余量。

对任意 `lambda_i>=0`，完整可行块组集合 `X_m` 给出有效上界：

```
U(lambda) = sum_m max_{x_m in X_m} sum_i (1+lambda_i)*A_im(x_m)
            - sum_i lambda_i*(q_i+m_i) - sum_i m_i.
```

算法对每块枚举满足并发数的全部可用波束子集；固定波束子集时，其他波束对用户的干扰不取决于其服务的用户身份，因此可逐波束选择加权服务最高的用户，得到该价格下全域资源支持函数。使用非负投影次梯度调整价格，并保留找到的最小有效上界；次梯度停止不意味着对偶或原问题最优。每次迭代均完成所有块定价才记录界。

默认最多 40 次价格迭代、45 秒软预算；单块最多 18 个不同候选波束、20 万个合法子集，累计最多 150 万个子集。超时或规模过大时自动退回原有 UB1 基数放松上界；报告 `pricingComplete`、`kind` 和 `pricingStatus`，不将未枚举完整的结果当作全域上界。计算时间在对比实验之后单列，不计入某种算法耗时。

已完成且严格逐用户满足 QoS 的日程，重新由原评价器检查，其最大保证总服务是可行下界 `L`。设有效上界为 `U`、某方法的可行值为 `V`，未知的真实整数最优值满足 `L <= V* <= U`，该方法的绝对最优差距属于 `[L-V, U-V]`。`theoretical_bound_by_run.csv` 中 `gapAtLeastBits` / `gapAtMostBits` 即此区间；百分比相应为 `[1-V/L, 1-V/U]`。没有达标日程时下界与差距显示 NaN，上界仍是有条件的界，不能据此声称问题可行。

此上界针对**确定性周期保证服务模型**，不是随机衰落下平均总速率的上界；上界不一定可达，也不是自动证明精确最优。浮点计算附带小量向上裕量，不是区间算术证明。

## 读取已有 MATLAB 实验，不重跑算法

把 V4 的 `matlab` 目录加入路径，然后：

```matlab
addpath('D:\code\LEO_QoS_Comparison_v4\matlab','-begin')
rehash
[theory,fig] = run_leo_theory_from_saved();
```

在弹窗选择原实验 `results\comparison\benchmark.mat`（若不存在可选 `raw_benchmark.mat`）。图和 CSV 保存到该 MAT 文件所在目录。注意选择本人那次实验的数据，不要将不同用户/码本场景的界交叉比较。

另可指定参数，例如 `options.maxSeconds=90`、`options.maxIterations=100`；更久不保证一定更紧。小规模完整枚举验证：`test_leo_theory_bound()`。
