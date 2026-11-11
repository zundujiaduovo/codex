% 对已有64用户结果收紧公平上界并检查Tabu改进动作；不重新运行四个方法。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
sourceDirectory=leo_v13_saved_directory(comparisonRoot,false);
[diagnosis,diagnosticFiles]=run_leo_v13_diagnose(sourceDirectory,struct(),true);
v13Figures=run_leo_v12_show_results(fullfile(sourceDirectory,'diagnosis'),'V13');
if ispc, winopen(fullfile(sourceDirectory,'diagnosis')); end
