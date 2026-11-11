% V12目标变化：先最大化未封顶min_i G_i/q_i，再保持阶段1公平提高总保证服务。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
if exist(fullfile(comparisonRoot,'CHECK_V12_INSTALLATION.m'),'file')~=2
    error('leo:v12IncompleteInstallation','Extract V12_complete_source_update.zip directly into this project root, keeping results/.');
end
CHECK_V12_INSTALLATION(comparisonRoot);
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
v12Directory=fullfile(comparisonRoot,'results','v12_uncapped_lexicographic');
[report,files]=run_leo_v12_comparison(v12Directory,struct(),true);
if ispc, winopen(v12Directory); end
v12Figures=run_leo_v12_show_results(v12Directory);
