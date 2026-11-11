% 主实验和固定公平目标时间图；64用户、128阵元、16并发。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V14_INSTALLATION(comparisonRoot);
[v14Options,v14Folder]=V14_SETTINGS();
v14Directory=fullfile(comparisonRoot,'results',v14Folder);
[report,files]=run_leo_v14_comparison(v14Directory,v14Options,true);
run_leo_v12_show_results(v14Directory,'V14');
if ispc, winopen(v14Directory); end
