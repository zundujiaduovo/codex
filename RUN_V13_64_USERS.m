% V13基于V12：64用户、64波束、最多16人并发；保留未封顶公平优先目标。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
v13Directory=fullfile(comparisonRoot,'results','v13_from_v12_64users_16streams');
[report,files]=run_leo_v13_comparison(v13Directory,struct(),true);
v13Figures=run_leo_v12_show_results(v13Directory,'V13');
if ispc, winopen(v13Directory); end
