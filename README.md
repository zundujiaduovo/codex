# LEO QoS V17：64轨迹 GPU bSB，含内存修正

[下载完整GPU源码包](LEO_QoS_V17_GPU64_memory_safe.zip)。分支 `leo-qos-v17-fairness-first-proxy-parallel-sb`。
本次在 V17 `0536bb5` 上加入GPU和内存修正；原V17基于V16 `4b5ea77`。
物理设置：64用户、128阵元（16×8）、64波束、每槽最多16人。

重启MATLAB释放原64进程池的内存，解压到新目录并进入该目录，运行：

```matlab
clear functions
RUN_COMPARISON
```

默认 `backend='gpu'`，设备1。启动时自动关闭CPU池，打印 `V17 GPU ACTIVE`、GPU型号、可用显存、轨迹数和精度。
64条轨迹组成一个GPU矩阵，不创建64个MATLAB进程。需要Parallel Computing Toolbox及MATLAB识别的NVIDIA GPU。
用户设备已识别为RTX 5060、8GB显存；GPU动力学默认单精度，Ising能量、原目标评分、约束修复与验收保留CPU双精度。
Tabu最先运行，仍使用CPU；bSB的矩阵动力学使用GPU，Local、Proxy+Tabu、上界认证也使用CPU。

结果保存到 `results/v17_gpu64_memory_safe`，含 MAT、CSV、性能/迭代/工作量图。
`execution_runtime.mat` 保存实际设备和初始化耗时，`v17_coordination_rounds.csv` 的 `gpuTrajectorySteps` 记录GPU积分轨迹步数。
新目录避免与旧CPU协议冲突。

- `RUN_COMPARISON`：Tabu、SB、Local、Proxy+Tabu、Greedy主实验。
- `RUN_V17_BOUNDS`：独立原问题上下界认证，可续算，不重跑主实验。
- `RUN_V17_CONTROLS`：同门槛同初值吞吐对照；同QUBO、同初始随机数和精度的GPU/CPU动力学对照、修复损失、求解质量区间。
- `RUN_V17_ALL`：依次运行以上三项。
- `SHOW_V17_RESULTS`：打开结果；`TEST_V17`：小规模回归、实际GPU可用时的GPU测试和原问题证书测试。

设置集中在 `V17_SETTINGS.m`。GPU动力学可选 `'precision','double'`；RTX 5060默认采用single，最终候选仍按双精度原式评价。
若要CPU并行，把 `m.execution.backend='cpu'`、`m.parallel.enabled=true`，并更换 `folder` 为新名字；备用池默认4个worker、每批8条轨迹。
GPU与CPU的单次耗时和找到的解质量应通过对照实验测量，小QUBO可能受GPU启动、传输和内核调用开销影响。

内存修正：详细候选记录默认最多2000行；每轮完整调度/价格矩阵默认不保存，标量收敛曲线保留。
内存不足时记录错误位置、关闭CPU池并跳过后续方法，保留已完成方法检查点。中断方法的进度快照不是完整随机搜索链续算。

公平搜索、代理增益校准、阶段2发现更高公平后返回阶段1的逻辑保留。默认没有时间或外层最大迭代次数限制；停止是经历扰动恢复后的经验停滞。
接近全局最优的结论仍由独立有效上下界判断。修改和验证范围见 [V17_CHANGELOG.md](V17_CHANGELOG.md)。

云环境没有MATLAB，未在这里执行MATLAB GPU测试或测量RTX 5060加速。已提供CPU参考动力学、GPU能量一致性和真实GPU运行测试，供本机执行。
