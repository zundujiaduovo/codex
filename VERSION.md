# LEO QoS Comparison V14 — based on V13, normalized fairness coordination

分支：`leo-qos-v14-from-v13-fairness-coordination`；基于V13提交`54f7412`。源码包：`LEO_QoS_Comparison_v14_from_v13_fairness_coordination.zip`。

V14实现用户指定的七项决策改进：单纯形平滑公平价格、2～3块联合补偿、增益误差可信域、上下文候选池及成本/收益调度、自适应bSB及有界松弛编码、共同干扰弦线McCormick/RLT有效上界、固定目标和两类独立控制。场景保持64用户/128阵元/16并发。见[V14_FROM_V13.md](V14_FROM_V13.md)。V14入口`RUN_V14_ALL`；`RUN_COMPARISON`指向V14主实验。

## V13历史版本：64 users / 128 antennas / 64 beams / 16 streams

当前源码包：`LEO_QoS_Comparison_v13_128ant_proxy_refinement.zip`。基于提交`82300fa`，增加外层120/60轮、每轮主代理刷新及候选切点重建、多候选原目标重评分及瓶颈用户候选。新增五配置单项对照和改进来源导出，默认目录`v13_proxy_refinement_combined`。图及窗口明确上界可达性未证实。沿用用户要求，本次未运行仿真或测试。详见[V13_PROXY_REFINEMENT.md](V13_PROXY_REFINEMENT.md)。

此前128阵元初版源码包为`LEO_QoS_Comparison_v13_64users_128ant_iterations.zip`，提交`82300fa`；见[V13_128ANT_ITERATIONS.md](V13_128ANT_ITERATIONS.md)。

## 此前64阵元V13记录

分支：`leo-qos-v13-from-v12-64users-16streams`。
基于V12提交`3a004695eb6f2ad90fe8be9b6b05de6e2017d6bc`。
源码包：`LEO_QoS_Comparison_v13_from_v12_64users_16streams.zip`。

扩大为64用户、64固定波束、每槽至多16人（1/4波束准入）；16射频链，每流10 W，总功率上限160 W。码本网格过采样由2改为4以提供足够的合法码字。固定64用户位置表前32人继承V12。

优化目标、SB/Local内层、外层验收和原式Tabu/贪婪保持V12逻辑。默认四方法同场景配对；独立V13版本标识、目录、数据和图，旧V12配对继续兼容。`RUN_V13_64_USERS`或`RUN_COMPARISON`运行新场景。见[V13_FROM_V12.md](V13_FROM_V12.md)。

V13更新：默认启用按原模型有效界差距/停滞的提前停止，120秒保留为最长预算；阈值集中在`V13_SETTINGS.m`。新运行方法名统一为Tabu、SB、Local、Greedy，旧结果可只重画标签。自适应实验独立写入`_adaptive`目录，分阶段停止原因和有效差距导出CSV。见[V13_ADAPTIVE_STOPPING.md](V13_ADAPTIVE_STOPPING.md)。

V13规模诊断更新：500步/32轨迹SB、32个Local起点、12步等价向量局部改进、每2轮刷新；延长停滞窗口。新增实际Tabu动作和冻结代理/价格/内层提案的事后对照，新增不受18波束枚举限制的人数条件配置LP对偶公平上界；旧数据可独立分析，原方法成绩不改。默认新目录`v13_64users_scaled_audit`。见[V13_SCALING_DIAGNOSIS.md](V13_SCALING_DIAGNOSIS.md)。

## V12历史版本

分支：`leo-qos-v12-uncapped-lexicographic-fairness`。
基于 V11 提交 `37bbe3d72cbb13b26fa1e6a5384391afddd64020`；沿用 V10/V11 的物理场景和保证服务证书，**改变优化目标**。
源码包：`LEO_QoS_Comparison_v12_uncapped_lexicographic.zip`。

1. 最大化 `min_i G_i(x)/q_i`，不在 1 处封顶，不因全员达标跳过公平搜索。
2. 固定第一阶段取得的公平水平 `s0`，在全员 `G_i/q_i>=s0` 的条件下提高总保证服务。

修改原目标评价、初始化择优、辅助变量界、价格辅助解、代理误差界、MILP、恢复和原模型上界。新增全域公平证书、按各自 `s0` 明确区分的条件吞吐证书、两阶段导出和公平保持复核。
SB/Local 使用 V10/V8 外层的 V12 适配版本；9 个历史 V8 冻结文件不变。原目标 Tabu 同样按未封顶公平搜索。

`RUN_COMPARISON` 和 `RUN_V12_LEXICOGRAPHIC` 默认运行新目标并自动打开图。V10/V11 的封顶目标通过历史入口显式保留，结果和证书不混用。
算法达到的公平值与已认证的全局最大公平值分开报告；是否证明第一阶段接近最优由原模型公平证书决定。

定义见 [V12_LEXICOGRAPHIC.md](V12_LEXICOGRAPHIC.md)，验证见 [V12_VALIDATION.md](V12_VALIDATION.md)。

V12 验证扩展：新增原生迭代/记录工作量与共同公平达标时间、只增补原式贪婪、固定代理下原式/代理精确块对照、K/M 经验规模实验；原优化目标和原三方法成绩保留。见 V12_PERFORMANCE_VALIDATION.md。

安装修复：新增计算前依赖/路径检查及完整平铺源码更新包，避免只覆盖入口或多解压一层导致诊断函数缺失；`RUN_V12_ALL_FIGURES` 统一运行全部图。更新包不含 results，已有配对结果继续复用。见 INSTALL_V12_UPDATE.md。
