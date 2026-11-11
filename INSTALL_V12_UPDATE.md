# 修复 V12 新函数缺失或路径混用

如果 `run_leo_v12_summary` 已调用 `run_leo_v12_diagnostics`，但 MATLAB 找不到后者，说明新入口的依赖没有被正确加载。完整发布包含该函数及三个依赖：`leo_v12_load_report`、`leo_v12_diagnostic_data`、`leo_build_v12_diagnostic_specs`。

使用仓库根目录的 **V12_complete_source_update.zip**。这是完整源码的平铺更新包，ZIP 内直接是根目录脚本和 `matlab/`，没有额外外层目录，也没有 `results/`。可直接解压到原项目目录，覆盖源码并保留已有计算结果。

下载更新包后，在 MATLAB 运行：

```matlab
projectRoot='D:\code\LEO_QoS_Comparison_v12_uncapped_lexicographic';
[zipName,zipDirectory]=uigetfile('*.zip','选择 V12_complete_source_update.zip');
assert(~isequal(zipName,0),'未选择更新包。');
unzip(fullfile(zipDirectory,zipName),projectRoot);
cd(projectRoot)
clear functions
addpath(fullfile(projectRoot,'matlab'),'-begin'); rehash
CHECK_V12_INSTALLATION
RUN_V12_ALL_FIGURES
```

首次检查须显示 `PASS: V12 installation complete`。检查只核对依赖文件及 MATLAB 实际解析路径，不重新求解或修改结果。
全部图入口复用已有三方法结果，按需补贪婪、执行代理诊断及规模实验；默认规模实验36次方法运行，每次60秒保护预算。

如只想重画已有结果的原生迭代图，通过安装检查后运行 `PLOT_V12_ITERATIONS`。

路径冲突时，检查会打印实际加载文件和应加载文件。使用 `which run_leo_v12_summary -all`、`which run_leo_v12_diagnostics -all` 定位重复版本；若当前项目根目录中另有同名函数，应移走或改名该副本，保留正式的 `matlab/` 版本。无需清空整个 MATLAB 路径，也无需删除 `results/`。
