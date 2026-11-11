% 只打开已有V13性能/原生迭代/工作量图，不重新搜索。
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
v13Directory=leo_v13_saved_directory(comparisonRoot,true);
run_leo_v13_replot(v13Directory,true);
v13Figures=run_leo_v12_show_results(v13Directory,'V13');
