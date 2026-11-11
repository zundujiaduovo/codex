clear functions
comparisonRoot=fileparts(mfilename('fullpath')); CHECK_V14_INSTALLATION(comparisonRoot);
[~,folder]=V14_SETTINGS(); directory=fullfile(comparisonRoot,'results',folder);
run_leo_v12_show_results(directory,'V14');
