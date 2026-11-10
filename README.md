# LEO QoS V11（基于 V10）：多种子配对验证与 SB／Local 内层对照

[下载 V11（基于 V10）纯源码包](LEO_QoS_Comparison_v11_based_on_v10.zip)。分支 `leo-qos-v11-from-v10-paired-sb-validation`，基于 V10 提交 `26759eac9899da48b0e30da38c880e6d44a757da`。

V10 已在用户的 Windows MATLAB 单种子实验中获得 SB 114.309 Mbit/周期、距共同上界约 0.794% 的结果。
V11 保留这项已有证据，沿用 V10 的搜索引擎和原问题，新增多种子重复和内层贡献对照。
协议见 [V11_FROM_V10.md](V11_FROM_V10.md)，实测见 [V11_VALIDATION.md](V11_VALIDATION.md)。

## V11 完整配对实验

解压至 `D:\code\LEO_QoS_Comparison_v11_based_on_v10`，运行 `RUN_V11_PAIRED.m`，或执行：

```matlab
clear functions
comparisonRoot='D:\code\LEO_QoS_Comparison_v11_based_on_v10';
cd(comparisonRoot)
addpath(fullfile(comparisonRoot,'matlab'),'-begin')
rehash
out=fullfile(comparisonRoot,'results','v11_based_on_v10_paired');
experiment=run_leo_v11_paired(out,struct(),true);
innerAudit=run_leo_v11_inner_control(out,struct(),true);
winopen(out);
```

默认在同一 V10 模型上比较 20 个搜索种子，每种子运行 Tabu、SB、配对 Local，各给 120 秒；
串行搜索预算约 2 小时，另有一次最多 600 秒的共同上界、独立衰落验证和内层对照。
已保存的完整配对可恢复，协议不同使用新目录。原 `RUN_COMPARISON.m` 仍运行 V10 的单次比较。

`paired_statistics.csv` 给出配对差值、置信区间、胜／平／负和检验；
`target_success_summary.csv` 给出达到共同质量门槛的次数；
`inner_control_*.csv` 固定代理、权重和旧组比较内层，并检查原问题验收收益。
所有最终日程和成绩均由原认证服务公式复核；独立衰落平均吞吐与认证目标分列。
`run_leo_v11_verify_exports(out)` 可以从导出的 CSV 和原模型快照重新核验全部日程的原目标及 QoS，无需重新搜索。
源码 ZIP 不含仿真输出；仓库的 `validation/` 单独保存实际执行证据。

## 以下保留 V10 的模型与单次比较说明

[V10 原分支](https://github.com/zundujiaduovo/codex/tree/leo-qos-v10-v8-search-metrics)保留原源码和发布包。

恢复V8的SB blockwise搜索，保留V9的原目标Tabu、独立起点Tabu、Local对照、共同上界、绘图和独立衰落验证。冻结引擎来自V8提交cd4ba09，9个文件只替换函数标识符；不混入V9扰动、多候选或联合搜索。新增配对的V8 Local对照，区分SB内核贡献与外层机制。

保持32用户、8×8天线、32波束、最多8人、主种子71669974和原概率证书。目标仍是全员QoS约束下最大化保证总服务。公平比例封顶为1是约束已满足。数学定义、默认8项方法、指标含义与缺失值规则见 [V10_METHOD.md](V10_METHOD.md)。

## MATLAB命令窗口完整运行

解压至D:\code\LEO_QoS_Comparison_v10后执行：

```matlab
clear functions
comparisonRoot='D:\code\LEO_QoS_Comparison_v10';
cd(comparisonRoot)
addpath(fullfile(comparisonRoot,'matlab'),'-begin')
rehash
opts=struct('budgetSeconds',120,'seeds',71669974);
opts.theoryOptions=struct('maxSeconds',600,'relativeGap',1e-5);
[report,fig]=run_leo_comparison(fullfile(comparisonRoot,'results','comparison_120s'),opts,true);
winopen(report.options.outputDirectory);
```

也可打开RUN_COMPARISON.m运行，默认预算相同。SB方法名称为sb_v8_blockwise；local_v8_blockwise是相同V8外层的Local对照。V9实验性SB仍可显式选择，默认已移出。

每次输出按seed_71669974及_run后缀隔离；自动保存并打开收敛图和performance_metrics四联图。每方法预算可改opts.budgetSeconds；上界通过opts.theoryOptions独立延长。重跑相同秒数的最终分数仍受机器速度和计时截断影响，不保证等于旧日志中的114.309。

## 新指标怎样看

- time_to_quality.csv：达到距上界5%、2%、1%、0.5%的首次记录时间。NaN表示没达到或未知，不填成120秒。
- quality_at_deadlines.csv：同样1、5、10、30、60、120秒时各方法已知解的质量；缺失区间留空。
- performance_summary.csv：同一评价窗口的平均界差，以及已有Jain、QoS余量和独立验证指标。方法提前交付日程后，该日程在后续截止时仍可使用。
- proxy_error_summary.csv：固定代理的非参考点误差；不把相切点必然近零的误差当作全域准确证明。

新指标不保证SB占优：更快、最终更好、过程平均更好、代理更紧是不同结论，应依据数据分别判断。单种子只能描述该实例，不能证明稳定性或普遍优势。

## 给已有V8/V9结果加指标，无需重新搜索

```matlab
source='D:\code\LEO_QoS_Comparison_v8\results\comparison_120s\seed_71669974\benchmark.mat';
metricDir=fullfile(fileparts(source),'performance_metrics_v10');
[metrics,files]=run_leo_performance_metrics(source,metricDir,struct(),true);
for k=1:numel(files)
    [~,~,ext]=fileparts(files{k});
    if strcmpi(ext,'.fig'), openfig(files{k},'new','visible'); end
end
winopen(metricDir);
```

这会读取已保存的共同上界和轨迹；旧数据没有的检查点不补造。若源文件没有上界，相关界差/达标时间指标留空。现有每SB收敛图仍可用run_leo_sb_convergence重画。

可预先覆盖共同门槛与截止时间：opts.performanceOptions=struct('gapTargetsPercent',[5,2,1,.5],'deadlinesSeconds',[1,5,10,30,60,120])。所有方法使用同一组设置，不按某个方法获胜与否选择指标。

## 验证

```matlab
test_leo_v10
test_leo_method
test_leo_benchmark
test_leo_sb_convergence
test_leo_branch_price
```

Python可用时，运行python tools/check_v8_snapshot.py可核对冻结文件仅做了标识符替换。冻结引擎的固定轮数轨迹、手算质量时间指标、晚达标和缺失数据、参考点以外的代理误差均有检查。云端数值使用Octave、图形规格使用Python验证，Windows MATLAB桌面未实机测试。上界定义及冻结概率模型分别见CERTIFICATE_SEARCH.md和FULL_QOS_MODEL.md。
