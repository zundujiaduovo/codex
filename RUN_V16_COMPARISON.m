clear functions
root=fileparts(mfilename('fullpath')); CHECK_V16_INSTALLATION(root);
[options,folder]=V16_SETTINGS(); directory=fullfile(root,'results',folder);
parallelRuntime=leo_v16_prepare_parallel(options.method.parallel);
if ~exist(directory,'dir'), mkdir(directory); end
save(fullfile(directory,'parallel_runtime.mat'),'parallelRuntime','-v7');
[report,files]=run_leo_v12_comparison(directory,options,true,'V16');
run_leo_v14_targets(report,directory,true);
run_leo_v14_evidence(report,directory);
run_leo_v12_show_results(directory,'V16');
if ispc, winopen(directory); end
