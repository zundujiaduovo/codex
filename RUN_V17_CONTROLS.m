clear functions
root=fileparts(mfilename('fullpath')); CHECK_V17_INSTALLATION(root);
[options,folder]=V17_SETTINGS(); directory=fullfile(root,'results',folder);
assert(exist(fullfile(directory,'benchmark.mat'),'file')==2,'Run RUN_COMPARISON first.');
leo_v16_prepare_parallel(options.method.parallel);
run_leo_v14_common_floor(directory,fullfile(directory,'common_floor'),true,2.60);
run_leo_v14_kernel_control(directory,fullfile(directory,'fixed_qubo'),true);
run_leo_v12_show_results(directory,'V17');
