# LEO QoS Comparison V11 based on V10

分支 `leo-qos-v11-from-v10-paired-sb-validation`，基于 V10 `26759eac9899da48b0e30da38c880e6d44a757da`。
源码包 `LEO_QoS_Comparison_v11_based_on_v10.zip`。
新增 20 搜索种子配对实验、Tabu／SB／配对 Local 的置信区间、达标次数、恢复保存和固定子问题内层对照。
V10 已有用户 MATLAB 证据和 V11 云端实测分别记录，见 V11_FROM_V10.md 和 V11_VALIDATION.md。

以下为继承的 V10 搜索和评价机制：

恢复V8 cd4ba09的SB blockwise搜索，9个文件只做函数标识符命名空间替换，保留原初态/随机流、候选排序、修复/扫描、验收、恢复与刷新。V8_SEARCH_SNAPSHOT.json及check_v8_snapshot.py核对原文SHA。配对Local也使用同一冻结V8外层。

保留V9原目标Tabu（公共/独立起点）、交换、Local候选池及两块Local、共同上界/验证与图形。默认8项；V9实验性SB不再默认启用。冻结模型、32用户、8×8、32波束、最多8人、71669974及全员QoS目标不变。

新增预设共同门槛的到达质量时间、定时质量、共同窗口平均界差与QoS余量，未达到或缺失不补造耗时。新增固定代理的非参考点误差审计，不以切点误差证明整体准确。指标只做事后评价，不改变或指导搜索。默认每方法120秒，上界独立600秒、目标0.001%。

源码包无验证结果、图、MAT、CSV或旧版本ZIP；检查方式与运行环境限制见README。
