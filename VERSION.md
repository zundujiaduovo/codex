# LEO QoS Comparison V8

分支leo-qos-v8-sb-convergence；纯源码包LEO_QoS_Comparison_v8.zip。

增加每种SB的独立收敛图及汇总时间对照图。已有V7 benchmark.mat/plot_data.mat可直接重画，不重跑算法；新运行增加已保存原目标改进的时间检查点。图含服务/时间、公平/时间、阶段局部轮数、代表性固定Ising调用能量，缺失阶段留空，不拼接不同问题的能量。

沿用V7的物理参数、固定种子71669974、14项方法与预算设置、搜索验收规则和证书求解器。日志开销计入实际算法时间。主入口自动导出新增图；基本18类图保持兼容。

包内只有源码、测试代码和必要文档，无验证输出、图像、MAT、CSV或旧ZIP。数值/日志/解压后检查与图形规格在Octave/Python验证，MATLAB桌面图形未实机运行。
