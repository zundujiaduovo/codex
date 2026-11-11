% 补原式贪婪对照，已有Tabu/SB/Local不重新运行。四方法输出另存greedy_control。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
v12Directory=fullfile(comparisonRoot,'results','v12_uncapped_lexicographic');
[greedyReport,greedyFiles]=run_leo_v12_greedy_control(v12Directory,struct(),true);
v12Figures=run_leo_v12_show_results(fullfile(v12Directory,'greedy_control'));
