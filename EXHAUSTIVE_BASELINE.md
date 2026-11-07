# 原始问题穷举对照

> 版本说明：本文原有数值是 `slot_union` 逐槽保守模型的历史结果。2026-11-07 的默认周期模型、公式与新验证见 [PERIODIC_QOS.md](PERIODIC_QOS.md)；不能把旧结果当作新版默认结果。

本基线直接使用方案 R5–R6 的统计设计速率和 O2/O4 两阶段目标。
没有切线、QUBO、SB、候选筛选、近似速率或逐块贪心。

## 运行实际可完成的算例

```matlab
addpath('matlab');
[model,comparison] = run_leo_exhaustive_demo();
result = model.exhaustive;
result.status                       % 'optimal' 才表示完整搜索完成
result.completed                    % true
result.visitedSchedules              % 16777216（本次运行）
result.x                            % K×M 二元完整日程
result.fairness                      % 先最大化的公平比例
result.totalBits                     % 该公平水平下的最大总设计服务
result.service.userBits              % 各用户周期设计服务
```

默认对照缩小为 **8 用户、3 个 50 ms 时间块**（15 个 10 ms 基本槽，总时长 150 ms）。
保持 32 固定波束、最多 8 人并发、每流 10 W、全部物理与统计模型。
这是较小的独立算例，不是原 32 用户/20 块问题的解；周期风险按这个算例全部候选位置重新分配。
本次用户各自占用不同预指派码字，每块有 256 个合法组，完整日程数为 256³=16,777,216。

## 实际对比结果

GNU Octave 9.4.0、固定种子 20261104。本次完整穷举及组服务预计算约 2.72 秒，
不包含物理建模时间；耗时不是跨机器性能保证，也尚未在 MATLAB 本体实测。

| 方法 | 公平比例 s | 周期总设计服务 / Mbit |
|---|---:|---:|
| 原轮换示例 | 0.502655349 | 5.308268506 |
| 最大流可行见证 | 0.167419582 | 1.770249936 |
| 完整穷举，公平优先/吞吐次优 | **0.502761118** | **4.530959580** |

三者使用同一个小问题、同一风险预算、同一组信道系数及原始服务评价器。
严格字典序先最大化公平，即使公平只增加少量，也不能用更大的吞吐换取较低公平。
因此最优日程的总服务低于轮换示例符合当前目标，不能据此判为搜索错误。
没有启用第 20 节吞吐底线或公平容忍度。

本次最优日程（用户编号从 1 开始）：

| 时间块 | 服务用户 |
|---|---|
| 1 | 1、3、4、5、6、7、8 |
| 2 | 1、2、3、4、5、6、7、8 |
| 3 | 1、2、3、5、7、8 |

默认同分时保留枚举顺序最早的日程；不同运行器的浮点细节可能使并列解不同。
结果比较和最优性声明均限于双精度下的原模型，不是任意精度符号证书。

本次实际导出数据在 `examples/`：`exhaustive_comparison.csv`（方法对比）、
`exhaustive_schedule.csv`（二元日程）、`exhaustive_user_service.csv`（逐用户服务）、
`exhaustive_summary.json`（规模/状态/耗时）。交付 ZIP 还包含
`examples/exhaustive_demo.mat`，其中 `snapshot` 是移除函数句柄后的实际小算例。
恢复问题可调用 `leo_form_problem(snapshot.parameters,snapshot.resources,snapshot.beams,snapshot.design)`。

## 对自己的模型调用

```matlab
p = leo_default_parameters();
p.system.K = 8;
p.time.nSlots = 15;
p.exhaustive.enabled = true;        % 接入原主函数
p.exhaustive.maxSchedules = 2e7;
p.exhaustive.maxSeconds = 120;
model = run_leo_sinr(p);
result = model.exhaustive;
```

也可以对已经形成的问题直接调用；直接调用本身就表示要求搜索，`enabled` 仅控制主函数：

```matlab
estimate = leo_exhaustive_size(model.problem.data);
options = leo_exhaustive_options();
result = leo_exhaustive_search(model.problem,options);
```

`run_leo_exhaustive_demo(p)` 接收到显式 p 时保留其规模，仅开启穷举，不自动改用户数或资源数。

## 搜索范围与算法

对资源 m，设每个可用波束 b 对应 n_b 个用户，合法组数为

\[
G_m=\sum_{\ell=0}^{\min(L,B_m)}[z^\ell]\prod_b(1+n_bz),\qquad
N_{\mathrm{schedule}}=\prod_mG_m.
\]

空组、单用户组和所有满足人数/同波束互斥的多人组均保留。
不可用用户被固定为 0，同一波束只允许选择其某一位用户。

1. `leo_exhaustive_size` 只计数，不生成指数规模候选。
2. `leo_enumerate_resource_groups` 对每个波束枚举“不使用/服务其中一位”，生成所有合法组。
3. `leo_resource_group_services` 缓存每组逐槽累加的原始设计服务 D_im。
4. `leo_exhaustive_search` 用混合进制索引遍历所有资源合法组的笛卡尔积。
   分批计算各日程的 D_i，不在内存中保存全部日程。
5. 严格比较 `(min(1,min(D_i/q_i)), sum(D_i))`：公平更高者优先，公平相同才比较吞吐。
   这一次遍历同时完成两个字典序阶段，没有将两个目标加权合并。
6. 最优完整日程再由既有 `problem.evaluate` 和 O2/O4 约束检查器独立复核。

缓存及批处理只减少重复计算和内存开销，不剪枝或跳过任何合法完整日程。
比较采用严格浮点大小关系，不通过公平容差允许较低公平日程替换最优值。

## 为什么不穷举原默认大问题

原默认 32 用户、20 块的前 13 块各有 3,228,226 个合法组，后 7 块各有 4,010,838 个。
因此完整日程数约 **6.90521093×10¹³⁰**，超过可完成搜索的规模。
大计数的 `totalSchedules` 是浮点近似，`countExactInDouble=false`；`log10Schedules≈130.83918`。
小算例的完整计数在双精度整数精确表示范围内。

默认保护选项：

| 字段 | 默认 | 含义 |
|---|---:|---|
| `enabled` | false | 仅控制是否从建模主函数启动搜索 |
| `maxSchedules` | 20,000,000 | 超过则不启动完整搜索 |
| `maxGroupsPerResource` | 100,000 | 单资源合法组数上限 |
| `maxMemoryBytes` | 256 MiB | 缓存及批处理工作区的估算上限 |
| `batchSize` | 65,536 | 每批完整日程数 |
| `maxSeconds` | 120 | 包含组服务预计算；每个资源/批次边界检查 |

时间预算是边界检查，可能超出一个预计算资源或批次的时间，不是实时硬截止。
提高上限不会解决大问题的指数复杂度。

| `status` | 含义 | 最优性 |
|---|---|---|
| `optimal` | 所有合法日程已评价 | `completed=true, optimal=true` |
| `size_limit` | 规模或内存估算超限，没有开始搜索 | 没有解，指标 NaN，`optimal=false` |
| `time_limit` | 预计算或搜索时间达到预算 | 可能有可行 incumbent，始终 `optimal=false` |

不把 `size_limit`、超时 incumbent、最大流见证或示例日程标为穷举最优。
问题模板的 `solved` 字段仍为 false，穷举完成状态与结果以 `model.exhaustive` 为准。

## 后续算法如何对比

在同一个 `model.problem` 上取得后续算法日程 `xNew` 后调用：

```matlab
assert(model.exhaustive.optimal);
rows = leo_compare_schedules(model.problem, ...
    {model.exhaustive.x,xNew},{'Exhaustive optimum','New algorithm'});
fairnessGap = rows(1).fairness-rows(2).fairness;
```

先比较公平比例，再在相同公平门槛下比较吞吐；不同公平水平下的吞吐不能单独判断字典序优劣。
比较不能重新采样用户/信道，或为某算法重新分配风险、改变时间块。
若与搜索耗时作比较，统一计入各算法应承担的预计算和建模时间；本次报告的 2.72 秒仅对应穷举调用。

测试入口 `test_leo_exhaustive` 包含独立原始二元位串枚举、跨块耦合、空组、
波束互斥、资源组数不等、批次一致性、公平封顶、零公平及未完成状态检查。
