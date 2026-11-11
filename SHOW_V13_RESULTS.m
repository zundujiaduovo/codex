% 只打开已有V13性能/原生迭代/工作量图，不重新搜索。
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
v13Directory=fullfile(comparisonRoot,'results','v13_from_v12_64users_16streams');
v13Figures=run_leo_v12_show_results(v13Directory,'V13');
