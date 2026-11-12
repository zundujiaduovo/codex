% 覆盖更新源码并保留results后，只重跑三种代理方法的第二阶段配对对照。
clear functions
comparisonRoot=fileparts(mfilename('fullpath')); CHECK_V14_INSTALLATION(comparisonRoot);
sourceDirectory=fullfile(comparisonRoot,'results','v14_from_v13_fairness_coordination');
if exist(fullfile(sourceDirectory,'benchmark.mat'),'file')~=2
    [~,folder]=V14_SETTINGS(); sourceDirectory=fullfile(comparisonRoot,'results',folder);
end
assert(exist(fullfile(sourceDirectory,'benchmark.mat'),'file')==2,'Keep the original V14 results folder in this project, or call run_leo_v14_stage2_repair with its full path.');
repairDirectory=fullfile(sourceDirectory,'stage2_repair_v2');
[stage2Repair,stage2Files]=run_leo_v14_stage2_repair(sourceDirectory,repairDirectory,true);
for j=1:numel(stage2Files)
    [~,~,extension]=fileparts(stage2Files{j});
    if strcmp(extension,'.fig'), openfig(stage2Files{j},'new','visible'); end
end
if ispc, winopen(repairDirectory); end
