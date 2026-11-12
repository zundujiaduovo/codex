% Saved-stage controls from the repaired V14 search, included in V15.
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V15_INSTALLATION(comparisonRoot);
[~,v15Folder]=V15_SETTINGS(); v15Directory=fullfile(comparisonRoot,'results',v15Folder);
assert(exist(fullfile(v15Directory,'benchmark.mat'),'file')==2,'Run RUN_V15_COMPARISON first.');
[commonControl,commonFiles]=run_leo_v14_common_floor(v15Directory,fullfile(v15Directory,'common_floor'),true,2.60);
[kernelControl,kernelFiles]=run_leo_v14_kernel_control(v15Directory,fullfile(v15Directory,'fixed_qubo'),true);
run_leo_v12_show_results(v15Directory,'V15');
