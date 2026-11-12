# LEO QoS V15：保留 V14 搜索修复，增加原问题全局认证

[下载 V15 完整源码包](LEO_QoS_Comparison_v15_from_v14_repaired_search_certified_bounds.zip)。
分支 `leo-qos-v15-from-v14-certified-original-bounds`，从 V14 提交 `59cb59d` 建立。
64用户、128阵元、64波束、16人并发，未封顶公平优先目标保持不变。

在 MATLAB 项目根目录执行 `RUN_V15_ALL`，依次运行五方法搜索、原问题上界认证、同公平门槛和固定QUBO控制。
只跑搜索用 `RUN_V15_COMPARISON`；只求界或继续断点用 `RUN_V15_BOUNDS`；看图用 `SHOW_V15_RESULTS`。
`RUN_COMPARISON` 现指向 V15 搜索。搜索设置直接继承修复后的 V14，包括第二阶段可信域中间候选和停滞扩展。

新认证使用真实逐时隙SINR服务、按需波束分支定价、配置LP与原调度二元分支，取消旧18波束枚举限制。
MATLAB内置实现，无需 SCIP、Python 或 Optimization Toolbox。
独立输出可行下界L、有效上界U、差距、未搜索节点与是否达到默认0.1%精度；工作量用完时明确保留“未认证达标”状态，重跑继续。
没有承诺64用户一次运行就能达到该精度。算法成绩与耗时不包含认证额外搜索。

已有 V14 结果也可直接认证：在 `V15_BOUND_SETTINGS.m` 设置 `sourceDirectory` 指向含 `benchmark.mat` 的结果文件夹，再执行 `RUN_V15_BOUNDS`，不用重跑算法。
完整公式、参数及输出见 [V15_FROM_V14.md](V15_FROM_V14.md)；覆盖更新可用 [V15平铺完整包](V15_complete_source_update.zip)，按 [安装说明](INSTALL_V15_UPDATE.md) 操作。
已提供独立Python/SciPy数学枚举检查和MATLAB小规模穷举测试入口；开发环境无MATLAB/Octave，未运行64用户仿真。

## V14 历史版本：公平协调与自适应 bSB

[下载V14完整源码包](LEO_QoS_Comparison_v14_from_v13_fairness_coordination.zip)。分支`leo-qos-v14-from-v13-fairness-coordination`，基于V13提交`54f7412`。物理场景为64用户、128阵元、64固定波束、每槽至多16人；继续未封顶公平优先目标。

已有工程更新请用[V14平铺完整更新包](V14_complete_source_update.zip)，直接解压到原项目根目录，保留`results/`。缺少`leo_v14_trust_path`或同名路径冲突时，按[安装修复说明](INSTALL_V14_UPDATE.md)操作；安装检查会分别显示缺失文件和实际加载路径。

解压到新目录，在MATLAB项目根目录运行`RUN_V14_ALL`，依次生成主实验、2.50/2.60/2.65/2.70公平达标时间、同门槛同初值的第二阶段控制，以及固定QUBO的四内核对照图。只跑主实验执行`RUN_COMPARISON`，补控制执行`RUN_V14_CONTROLS`，只看图执行`SHOW_V14_RESULTS`。

V14修改归一化平滑公平价格、瓶颈2～3块补偿、基于增益误差的可信域与刷新、保留补偿能力的候选池和收益调度、自适应bSB及有界松弛编码；新增共同干扰McCormick/RLT上界和真正利用公平门槛的吞吐界。设置在`V14_SETTINGS.m`。完整数学定义、对照范围和输出文件见[V14_FROM_V13.md](V14_FROM_V13.md)。本版不把自适应bSB标称为论文EC-bSB。

第二阶段停滞补丁：覆盖源码、保留原`results`后执行`RUN_V14_STAGE2_REPAIR`，即可复用已保存第一阶段，对旧/新第二阶段策略作同初值、同门槛、同种子配对重跑，不重跑第一阶段和上界。补丁保留可信域内部的中间候选，并在无进展时扩大搜索范围。完整重跑结果写入`results/v14_from_v13_fairness_coordination_stage2_v2`。未运行64用户补丁性能实验，改善幅度以实际结果为准。

## V13历史版本

[下载V13完整源码包](LEO_QoS_Comparison_v13_128ant_proxy_refinement.zip)。分支`leo-qos-v13-from-v12-64users-16streams`；本次从V13提交`82300fa`增加三项代理框架改进，目标仍为未封顶公平优先，再在取得的公平下限下提高总保证服务。

解压到独立的新目录，在MATLAB项目根目录运行：

```matlab
RUN_COMPARISON
```

默认五方法Tabu、SB、Local、Proxy+Tabu、Greedy。Tabu公平/速率阶段为2000/1000轮；三个代理方法为120/60价格轮，每轮刷新主代理、按候选偏差触发局部相切、多候选原目标重评分和瓶颈用户候选。关闭时间、停滞和上界差距提前停止。设置在`V13_SETTINGS.m`，完整说明见[V13_PROXY_REFINEMENT.md](V13_PROXY_REFINEMENT.md)。按先前要求本次未运行仿真或测试。

阵列16×8，共128阵元；准入比例16/64=1/4，射频链16、每流10 W、总功率上限160 W。MATLAB窗口打印上界公式、数值及松弛含义，另存`UPPER_BOUND_EXPLANATION.txt`。结果写入新目录`results/v13_proxy_refinement_combined`，自动保存数据并打开性能、迭代、工作量和候选诊断图。只看已有图执行`SHOW_V13_RESULTS`。

运行`RUN_V13_PROXY_ABLATIONS`可得到基线、仅增加迭代、仅刷新代理、仅增加候选、三项合并的五组对照及汇总图。`refinement_rounds.csv`记录接受来源及局部候选误差，判断提升来自哪里。全局松弛上界的可达性尚未证明，不把上界数值直接称为真实最优值。

## V12历史入口与说明

[下载 V12 纯源码包](LEO_QoS_Comparison_v12_uncapped_lexicographic.zip)。分支 `leo-qos-v12-uncapped-lexicographic-fairness`，从 V11 提交 `37bbe3d72cbb13b26fa1e6a5384391afddd64020` 继续开发。

已有项目需要更新时，使用 [V12 完整平铺更新包](V12_complete_source_update.zip)，直接解压到项目根目录，保留 `results/`。遇到新函数缺失或路径混用，按 [安装修复说明](INSTALL_V12_UPDATE.md) 操作；`CHECK_V12_INSTALLATION` 会在计算前核对依赖和实际加载路径。

**V12 改变了优化目标。** 先最大化跨全部时隙累计后的最差用户需求满足比例 `s=min_i G_i(x)/q_i`，允许 `s>1`；随后在每个用户的比例都不低于第一阶段所得 `s0` 的条件下，提高总保证服务 `sum_i G_i(x)`。
`s=1` 仅表示全员 QoS 达标，不再结束公平阶段。数学定义、代码变化和证书范围见 [V12_LEXICOGRAPHIC.md](V12_LEXICOGRAPHIC.md)，执行证据见 [V12_VALIDATION.md](V12_VALIDATION.md)。

## 运行 V12

解压源码包，在 MATLAB 中进入源码根目录，执行：

```matlab
RUN_V12_LEXICOGRAPHIC
```

全部图可执行 `RUN_V12_ALL_FIGURES`，依次复用原三方法结果、补贪婪、运行代理诊断和规模实验。规模实验的默认预算见下文验证说明。

`RUN_V12_LEXICOGRAPHIC`运行V12。默认同一个物理场景、一个搜索种子，比较原目标 Tabu、SB 和配对 Local；每方法 120 秒，另给公平上界 180 秒及各公平门槛的条件吞吐上界各 30 秒。搜索预算合计约 6 分钟，证书和独立衰落验证另计。

结果保存到 `results/v12_uncapped_lexicographic`，包含 MAT、CSV、JSON，以及 PNG/PDF/可编辑 FIG。根目录脚本结束时自动打开结果文件夹、六联图、原生迭代四联图和工作量/共同质量时间图。只查看已有图，执行 `SHOW_V12_RESULTS`，不重新搜索。

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

## 追加贪婪、迭代和计算量验证

已有 V12 结果可直接使用以下入口，详见 [V12_PERFORMANCE_VALIDATION.md](V12_PERFORMANCE_VALIDATION.md)：

```matlab
PLOT_V12_ITERATIONS      % 从已有MAT画各阶段原生迭代，不重新搜索
ADD_V12_GREEDY           % 只补原式贪婪，四方法另存greedy_control
RUN_V12_PROXY_CONTROL   % 固定代理/权重，在声明的受限块域内作精确对照
RUN_V12_SCALING         % 固定算法配置，测K/M规模、实际工作量及时间截断
```

SB/Local 的价格轮、Tabu 的邻域轮和贪婪的增量动作分别标注，迭代数不作为同等成本。新运行另记录内层耗时、代理构建/刷新、实际 `sum(N^2*R*steps)`；旧数据没有的细分指标保持未知。原方法的已存成绩保留，补贪婪不要求重跑三方法。

## V10/V11 的历史结果

V10/V11 的目标是全员 QoS 达标后最大化总保证服务，公平比例封顶为 1。V10 用户 MATLAB 单种子结果中的 SB 约 114.309 Mbit/周期、距共同吞吐上界约 0.794%，以及 V11 的配对结果，描述该历史目标。
V12 提高公平后可能减少总服务，这符合新目标；旧目标的约 115 Mbit/周期上界不能用来证明 V12 的公平最优性。

历史入口 `RUN_V11_PAIRED`、`SHOW_V11_RESULTS` 保留；原单次全员 QoS 比较改名为 `run_leo_full_qos_comparison`。协议见 [V10_METHOD.md](V10_METHOD.md)、[V11_FROM_V10.md](V11_FROM_V10.md)。
[V10 分支](https://github.com/zundujiaduovo/codex/tree/leo-qos-v10-v8-search-metrics)和 [V11 分支](https://github.com/zundujiaduovo/codex/tree/leo-qos-v11-from-v10-paired-sb-validation)保留各自源码与结果。

源码 ZIP 仅含源码和文档；云端实际执行记录单独保存在 `validation/`。云端使用 Octave 验证数值、Python 渲染共享图形规格；Windows MATLAB 桌面未实机测试。
