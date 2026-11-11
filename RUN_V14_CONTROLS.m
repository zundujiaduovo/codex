% 在已完成的主实验上增加同门槛阶段2、固定QUBO四内核对照。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V14_INSTALLATION(comparisonRoot);
[~,v14Folder]=V14_SETTINGS();
v14Directory=fullfile(comparisonRoot,'results',v14Folder);
assert(exist(fullfile(v14Directory,'benchmark.mat'),'file')==2,'Run RUN_V14_COMPARISON first.');
[commonControl,commonFiles]=run_leo_v14_common_floor(v14Directory,fullfile(v14Directory,'common_floor'),true,2.60);
[kernelControl,kernelFiles]=run_leo_v14_kernel_control(v14Directory,fullfile(v14Directory,'fixed_qubo'),true);
run_leo_v12_show_results(v14Directory,'V14');
