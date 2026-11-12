# LEO QoS V16：64起点并行，搜索至经验收敛

[下载完整源码包](LEO_QoS_V16_parallel64_convergence.zip)。分支 `leo-qos-v16-parallel64-until-convergence`，基于 V15 `97afd6c`。
64用户、128阵元、64波束、每槽至多16人；先最大化未封顶最差累计服务比例，再保持公平门槛提高总保证服务。

在 MATLAB 中进入解压后的新目录：

```matlab
clear functions
addpath(fullfile(pwd,'matlab'),'-begin'); rehash;
RUN_COMPARISON
```

- `RUN_COMPARISON`：五方法搜索、性能/迭代/工作量图。
- `RUN_V16_BOUNDS`：独立原问题上界认证；可续算，不重跑搜索。
- `RUN_V16_CONTROLS`：相同公平门槛阶段2、相同QUBO内核对照。
- `RUN_V16_ALL`：依次执行以上三项。
- `SHOW_V16_RESULTS`：打开已保存图；`TEST_V16`：小规模组件和证书测试。

SB为64条轨迹，使用 MATLAB Parallel Computing Toolbox 的实际 worker 池和 `parfor`；启动窗口打印 worker 数。
默认最多8个worker、每批8条轨迹。缺少该工具箱会在搜索前明确报错；只有显式关闭 `method.parallel.enabled` 才使用串行。
Local起点同步为64以保留起点数对照；Proxy+Tabu继续4个起点。搜索设置集中在 `V16_SETTINGS.m`。

Tabu、SB、Local、Proxy+Tabu 均取消外层时间和最大迭代次数限制。连续3个100轮窗口中，原目标每个窗口的累计提升都不超过
`max(1e-8, 1e-6*窗口初值)` 时，记录 `objective_plateau`。最少迭代：代理方法公平/吞吐240/120轮，Tabu为2000/1000轮。
有明显提升就继续。该条件表示经验收敛；全局最优性由独立证书判断。Greedy在无可改善添加动作时自然结束。

结果保存在 `results/v16_parallel64_until_convergence`。每个完成的方法独立保存并在重跑时复用；长搜索每25轮保存当前可行日程和历史。
中断中的方法重跑自身搜索，不能把可行解快照称为完整随机搜索链续算；已经完成的其他方法不重跑。
上界认证保留完整未搜索树，可精确续算。

仅保留 V16 入口及其运行依赖、两类必要测试和一个完整包；旧入口、旧安装包、旧结果和过时文档已从本分支清理。
旧版本可在原 Git 分支中查阅。详细规则、并行计算范围及认证公式见 [V16_CHANGELOG.md](V16_CHANGELOG.md)。

开发环境没有 MATLAB/Octave；已做源代码依赖、语法和独立数学检查，未在这里测量真实 MATLAB worker 加速或64用户效果。
