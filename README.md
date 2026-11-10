# LEO QoS V9：候选池、两块协调与原目标 Tabu 对照

[下载 V9 纯源码包](LEO_QoS_Comparison_v9.zip)。新分支：`leo-qos-v9-candidate-coordination`。只含完整源码、测试代码和文档，无仿真输出、MAT、CSV、图片或旧ZIP。

目标：**所有用户满足周期QoS，再最大化保证总服务**。封顶公平全为1是约束已经满足；主要性能指标改用保证总服务、距共同上界的差距及达到相同服务所需时间。数学逻辑、8项方法及实现边界见 [V9_METHOD.md](V9_METHOD.md)。

保持32用户、8×8天线、32波束、最多8人并发、种子71669974。候选池保留多个不同组按原目标筛选；增加停滞时两块候选组合；增加设置对应的Local对照与独立起点Tabu。原目标Tabu不接收或构建二次代理。合并重复默认对比，旧方法可显式选择；修正旧参考点消融未作用到吞吐阶段的问题。

## MATLAB 命令窗口完整运行

将源码包解压到D:\code\LEO_QoS_Comparison_v9，运行：

```matlab
clear functions
comparisonRoot='D:\code\LEO_QoS_Comparison_v9';
cd(comparisonRoot)
addpath(fullfile(comparisonRoot,'matlab'),'-begin')
rehash
opts=struct();
opts.budgetSeconds=120;
opts.seeds=71669974;
opts.theoryOptions=struct('maxSeconds',600,'relativeGap',1e-5);
[report,fig]=run_leo_comparison(fullfile(comparisonRoot,'results','comparison_120s'),opts,true);
winopen(report.options.outputDirectory);
```

也可打开根目录RUN_COMPARISON.m点击运行，默认预算相同。运行结果按种子隔离目录，重复运行追加_run后缀。SB汇总及各SB收敛图自动保存并在MATLAB中打开；图包括保证服务、相对上界差距、前15秒放大和代表性固定Ising调用。

修改opts.budgetSeconds可延长每方法预算；opts.method=leo_method_options(struct('originalSearchRounds',20000,'fairnessRounds',20000,'throughputRounds',20000))可延长轮数。上界的maxSeconds、maxNodes和relativeGap通过opts.theoryOptions独立设置。达到目标、无改善或轮数到限可提前停止；time_limit不代表全局收敛。

## 已有数据重画，不重新搜索

```matlab
source='D:\code\LEO_QoS_Comparison_v9\results\comparison_120s\seed_71669974\benchmark.mat';
out=fullfile(fileparts(source),'sb_convergence_redraw');
[files,specs]=run_leo_sb_convergence(source,out,true);
for k=1:numel(files)
    [~,~,ext]=fileparts(files{k});
    if strcmpi(ext,'.fig'), openfig(files{k},'new','visible'); end
end
winopen(out);
```

兼容V7/V8 benchmark.mat、raw_benchmark.mat和plot_data.mat。旧结果缺失共同上界时差距图留空，不伪造；原始日志未记录的中间改进不能事后恢复。PNG/PDF失败时可打开同目录FIG；长图注保留在FIG轴UserData和JSON中，避免遮挡曲线。

## 保存的评价依据

- runs.csv：是否全员达标、保证总服务、相对上界差距、初始化成绩及策略、是否使用二次代理、独立衰落指标与实际耗时。
- theoretical_bound_summary.csv、theoretical_bound_by_run.csv：同一QoS门槛下的模型最优区间和差距。额外证书搜索的可行日程独立标注，不计入某个方法的成绩。
- search_module_audit.csv、accepted_move_sources.csv：候选来源、非代理第一名的原目标验收、两块协调、SB/构建/后处理/恢复耗时与改进来源。
- benchmark.mat、raw_benchmark.mat、plot_data.mat和sb_convergence下CSV/JSON：重画所需数值与真实时间轨迹。

## 运行检查

```matlab
test_leo_v9
test_leo_polish_vectorized
test_leo_method
test_leo_benchmark
test_leo_sb_convergence
test_leo_branch_price
test_leo_pricing_oracle
```

云端以Octave检查数值、原始约束、无二次Tabu、缓存等价性、消融模式、日志和文件导出；图形规格用Python渲染检查。未在Windows MATLAB桌面实机运行。性能应以你的相同场景、相同预算下实际结果为准，不保证新方法对每个实例都更好。概率证书和目标见FULL_QOS_MODEL.md，上界求解见CERTIFICATE_SEARCH.md。
