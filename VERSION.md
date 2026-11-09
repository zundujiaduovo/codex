# LEO QoS Comparison V3

Git 分支：`leo-qos-v3-theoretical-bound`。运行包：`LEO_QoS_Comparison_v3.zip`，解压后目录同名。

V3 包含完整 MATLAB 建模与算法源码、原始方法和本次新增的周期 QoS 保证、12 项方法/消融对比、绘图和测试函数、Python 渲染脚本以及公式文档；不依赖旧版代码包。可选 Gurobi/Optimization Toolbox 未打包，缺失时相应方法标记不可用。

运行包也含历史示例图、CSV 汇总和少量重画所需 MAT 文件。它不包含仓库中全部历史 MAT 结果（约 172 MB）；运行新实验会在本地生成新的结果文件。

本分支根目录只保留本版的一个 ZIP，旧代码包和补丁仍在 `main`、`periodic-qos-20261107` 或 `leo-qos-v2-full-comparison` 分支。Git 不重复存储这些分支的相同历史对象。

在 MATLAB 切换到解压目录，运行 `RUN_COMPARISON`。默认 32 用户、12 项方法/消融、3 个算法种子，分别给每个方法 12 秒软预算。统计与指标定义见 `METHODS_AND_METRICS.md`。默认 1 Mbit/用户时部分公平指标可能封顶，见 README 的 2 Mbit 负载例子。

历史回归与新周期保证测试在 Octave 中验证；MATLAB 图形界面尚未在本构建环境验证。为避免混用不同版本，请解压到新目录，并将新目录的 `matlab` 添加到路径开头。

V3 新增：全用户 QoS 达标条件下的保证总服务有效上界、算法差距区间、上界图和 CSV；可直接读取已有 benchmark.mat，不重新运行方法。上界不是必然可达的精确最优值。详见 THEORETICAL_BOUND.md。
