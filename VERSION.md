# LEO QoS Comparison V13 — based on V12, 64 users / 64 beams / 16 streams

分支：`leo-qos-v13-from-v12-64users-16streams`。
基于V12提交`3a004695eb6f2ad90fe8be9b6b05de6e2017d6bc`。
源码包：`LEO_QoS_Comparison_v13_from_v12_64users_16streams.zip`。

扩大为64用户、64固定波束、每槽至多16人（1/4波束准入）；16射频链，每流10 W，总功率上限160 W。码本网格过采样由2改为4以提供足够的合法码字。固定64用户位置表前32人继承V12。

优化目标、SB/Local内层、外层验收和原式Tabu/贪婪保持V12逻辑。默认四方法同场景配对；独立V13版本标识、目录、数据和图，旧V12配对继续兼容。`RUN_V13_64_USERS`或`RUN_COMPARISON`运行新场景。见[V13_FROM_V12.md](V13_FROM_V12.md)。

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
