% V9：默认8项、每方法120秒、上界独立600秒；自动保存并打开SB收敛图。
clear functions
comparisonRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin');
rehash;
[report,fig] = run_leo_comparison(fullfile(comparisonRoot,'results','comparison'));
