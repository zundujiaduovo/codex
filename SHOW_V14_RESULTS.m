clear functions
comparisonRoot=fileparts(mfilename('fullpath')); CHECK_V14_INSTALLATION(comparisonRoot);
[~,folder]=V14_SETTINGS(); directory=fullfile(comparisonRoot,'results',folder);
if exist(fullfile(directory,'benchmark.mat'),'file')~=2
    directory=fullfile(comparisonRoot,'results','v14_from_v13_fairness_coordination');
end
run_leo_v12_show_results(directory,'V14');
