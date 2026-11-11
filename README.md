# LEO QoS V12：未封顶公平优先，再提高总保证服务

[下载 V12 纯源码包](LEO_QoS_Comparison_v12_uncapped_lexicographic.zip)。分支 `leo-qos-v12-uncapped-lexicographic-fairness`，从 V11 提交 `37bbe3d72cbb13b26fa1e6a5384391afddd64020` 继续开发。

**V12 改变了优化目标。** 先最大化跨全部时隙累计后的最差用户需求满足比例 `s=min_i G_i(x)/q_i`，允许 `s>1`；随后在每个用户的比例都不低于第一阶段所得 `s0` 的条件下，提高总保证服务 `sum_i G_i(x)`。
`s=1` 仅表示全员 QoS 达标，不再结束公平阶段。数学定义、代码变化和证书范围见 [V12_LEXICOGRAPHIC.md](V12_LEXICOGRAPHIC.md)，执行证据见 [V12_VALIDATION.md](V12_VALIDATION.md)。

## 运行 V12

解压源码包，在 MATLAB 中进入源码根目录，执行：

```matlab
RUN_V12_LEXICOGRAPHIC
```

`RUN_COMPARISON` 也运行 V12。默认同一个物理场景、一个搜索种子，比较原目标 Tabu、SB 和配对 Local；每方法 120 秒，另给公平上界 180 秒及各公平门槛的条件吞吐上界各 30 秒。搜索预算合计约 6 分钟，证书和独立衰落验证另计。

结果保存到 `results/v12_uncapped_lexicographic`，包含 MAT、CSV、JSON，以及 PNG/PDF/可编辑 FIG。根目录脚本结束时自动打开结果文件夹和六联图。只查看已有图，执行 `SHOW_V12_RESULTS`，不重新搜索。

自定义目录或运行多个配对搜索种子：

```matlab
clear functions
addpath(fullfile(pwd,'matlab'),'-begin'); rehash
o=struct('budgetSeconds',120,'seeds',71669974+(0:19)*104729);
out=fullfile(pwd,'results','v12_paired_20');
[report,files]=run_leo_v12_comparison(out,o,true);
run_leo_v12_show_results(out);
```

20 个搜索种子仍共用同一场景；三方法搜索预算合计约 2 小时。已保存的完整配对可恢复；协议变化时使用新目录。V10/V11 结果不能加载为 V12 配对。

## 读取结果

- `runs.csv`：第一阶段公平、第二阶段公平、固定门槛和原目标总服务。
- `stages.csv`：两阶段各自的初值、保存值和停止状态。
- `user_service.csv`、`schedules.csv`、`original_model.mat`：逐用户累计保证服务、完整二元日程和冻结原模型；`stage1_schedules.csv`、`stage1_user_service.csv` 同时保存第一阶段日程与成绩。
- `search_checkpoints.csv`：实际记录的阶段、时间、公平和总服务轨迹。
- `fairness_certificate_summary.csv`：原模型全局最大公平值的上下界及剩余差距。
- `conditional_throughput_bounds.csv`：在明确指定的各个 `s0` 下，总保证服务的条件上下界。

先比较公平，再比较同一公平门槛下的总服务。不同 `s0` 的总服务对应不同的第二阶段问题。时间受限的第一阶段结果是已取得的可行公平值；是否接近全局最大公平，应看公平证书。程序会单独标记是否在证书容差内确认，未闭合差距不标为已证明最优。

从导出日程直接重算原模型成绩并检查第二阶段公平保持：

```matlab
run_leo_v12_verify_exports(out)
test_leo_v12
```

SB/Local 仍用二次代理产生内层候选，全部最终日程、验收成绩和公平门槛均按原保证服务公式计算。Tabu 直接评价原模型邻域，不使用二次服务代理。独立衰落平均吞吐与保证服务分别保存。

## V10/V11 的历史结果

V10/V11 的目标是全员 QoS 达标后最大化总保证服务，公平比例封顶为 1。V10 用户 MATLAB 单种子结果中的 SB 约 114.309 Mbit/周期、距共同吞吐上界约 0.794%，以及 V11 的配对结果，描述该历史目标。
V12 提高公平后可能减少总服务，这符合新目标；旧目标的约 115 Mbit/周期上界不能用来证明 V12 的公平最优性。

历史入口 `RUN_V11_PAIRED`、`SHOW_V11_RESULTS` 保留；原单次全员 QoS 比较改名为 `run_leo_full_qos_comparison`。协议见 [V10_METHOD.md](V10_METHOD.md)、[V11_FROM_V10.md](V11_FROM_V10.md)。
[V10 分支](https://github.com/zundujiaduovo/codex/tree/leo-qos-v10-v8-search-metrics)和 [V11 分支](https://github.com/zundujiaduovo/codex/tree/leo-qos-v11-from-v10-paired-sb-validation)保留各自源码与结果。

源码 ZIP 仅含源码和文档；云端实际执行记录单独保存在 `validation/`。云端使用 Octave 验证数值、Python 渲染共享图形规格；Windows MATLAB 桌面未实机测试。
