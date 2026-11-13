# LEO QoS V17：公平优先、代理校准、64轨迹并行 bSB

[下载完整源码包](LEO_QoS_V17_fairness_first_parallel64.zip)。分支 `leo-qos-v17-fairness-first-proxy-parallel-sb`，基于 V16 `4b5ea77`。
物理设置：64用户、128阵元（16×8）、64波束、每槽最多16人。

解压到一个新目录，在 MATLAB 中进入该目录，运行：

```matlab
clear functions
RUN_COMPARISON
```

启动窗口会打印本版修改、64条轨迹及 worker 数、停止规则和输出位置。
结果保存到 `results/v17_fairness_first_proxy_parallel_sb`，包含 MAT、CSV 和性能/迭代/工作量图。
V16 的旧结果保留在原目录，V17 不将其当作本版结果复用。

- `RUN_COMPARISON`：Tabu、SB、Local、Proxy+Tabu、Greedy 五方法主实验。
- `RUN_V17_BOUNDS`：继续独立原问题上下界认证，不重跑主实验。
- `RUN_V17_CONTROLS`：同门槛同初值的吞吐对照；固定QUBO的求解质量、修复损失及串行/并行64轨迹对照。
- `RUN_V17_ALL`：依次运行以上三项。上界认证和对照实验另需计算时间。
- `SHOW_V17_RESULTS`：打开结果；`TEST_V17`：运行小规模回归、证书及并行等价测试。

参数集中在 `V17_SETTINGS.m`。默认不设时间或最大外层迭代次数限制；满足经验停滞条件才退出。
公平阶段还要经历最多4次无明显改善的原问题扰动恢复，每次48轮；有明显公平提升会重置计数。
“搜索停止”不等于全局最优，最优性由独立有效上下界判断。

主实验始终按 `(公平值, 总服务量)` 保存最佳解。吞吐阶段找到更高公平值时，即使总服务下降，也保存该解并返回公平阶段。
因此公平曲线不应回退；总服务曲线在公平提升时允许下降。同门槛吞吐对照保持固定门槛，独立考察第二目标。

bSB 默认64条轨迹，使用 Parallel Computing Toolbox 的真实 CPU worker 池和 `parfor`，默认最多8个worker、每批8条。
缺少工具箱会在搜索前报告；显式设置 `m.parallel.enabled=false` 可用串行模式。GPU 尚未实现。
固定QUBO对照中的 `SB adaptive serial` 执行与并行版相同的分批、随机种子和轨迹，用于测量真实并行收益。

每个完成的方法独立保存并可复用；中断的方法重跑自身搜索。进度快照不是完整随机搜索链续算。
上界认证保存完整未搜索树，可续算。当前分支只保留 V17 入口和一个完整源码包；共享数值函数保留原文件名以避免重复副本。

修改与验证范围见 [V17_CHANGELOG.md](V17_CHANGELOG.md)。云环境没有 MATLAB/Octave，未在此运行64用户实验或测量并行加速。
