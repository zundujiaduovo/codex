clear functions
root=fileparts(mfilename('fullpath')); CHECK_V17_INSTALLATION(root);
[options,folder]=V17_SETTINGS(); directory=fullfile(root,'results',folder);
leo_v17_print_changes(options);
parallelRuntime=leo_v16_prepare_parallel(options.method.parallel);
if ~exist(directory,'dir'), mkdir(directory); end
save(fullfile(directory,'parallel_runtime.mat'),'parallelRuntime','-v7');
[report,files]=run_leo_v12_comparison(directory,options,true,'V17');
run_leo_v14_targets(report,directory,true);
run_leo_v14_evidence(report,directory);
run_leo_v17_search_audit(report,directory);
run_leo_v12_show_results(directory,'V17');
if ispc, winopen(directory); end
