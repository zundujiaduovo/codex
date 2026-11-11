% 一次生成全部V12图：已有三方法结果复用；补贪婪、代理诊断及规模实验。
% 规模实验默认36次方法运行，每次60秒保护预算；原results保留。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
if exist(fullfile(comparisonRoot,'CHECK_V12_INSTALLATION.m'),'file')~=2
    error('leo:v12IncompleteInstallation','Extract V12_complete_source_update.zip directly into this project root, keeping results/.');
end
CHECK_V12_INSTALLATION(comparisonRoot);
run(fullfile(comparisonRoot,'RUN_V12_LEXICOGRAPHIC.m'));
run(fullfile(comparisonRoot,'ADD_V12_GREEDY.m'));
run(fullfile(comparisonRoot,'RUN_V12_PROXY_CONTROL.m'));
run(fullfile(comparisonRoot,'RUN_V12_SCALING.m'));
