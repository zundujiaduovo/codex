% V13：128阵元、五方法、三项代理改进合并配置，按最大迭代次数运行。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
[v13Options,v13ResultFolder]=V13_SETTINGS();
v13Directory=fullfile(comparisonRoot,'results',v13ResultFolder);
[report,files]=run_leo_v13_comparison(v13Directory,v13Options,true);
v13Figures=run_leo_v12_show_results(v13Directory,'V13');
if ispc, winopen(v13Directory); end
