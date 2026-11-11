% 只从已有V12 MAT导出原生迭代曲线、工作量和共同公平达标时间，不重新搜索。
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
v12Directory=fullfile(comparisonRoot,'results','v12_uncapped_lexicographic');
[v12Analysis,v12Files]=run_leo_v12_diagnostics(v12Directory,v12Directory,true);
v12Figures=run_leo_v12_show_results(v12Directory);
