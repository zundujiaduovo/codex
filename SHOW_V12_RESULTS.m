% 只查看已有V12图；缺图按JSON重画，不重新运行优化。
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
v12Directory=fullfile(comparisonRoot,'results','v12_uncapped_lexicographic');
v12Figures=run_leo_v12_show_results(v12Directory);
