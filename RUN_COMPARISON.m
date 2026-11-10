% V10：V8冻结搜索+V9对照，默认8项、每方法120秒、上界独立600秒。
clear functions
comparisonRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin');
rehash;
[report,fig] = run_leo_comparison(fullfile(comparisonRoot,'results','comparison'));
