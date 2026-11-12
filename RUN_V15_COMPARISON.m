% Five-method search, including the V14 phase-2 repair; fixed iteration caps.
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V15_INSTALLATION(comparisonRoot);
[v15Options,v15Folder]=V15_SETTINGS();
v15Directory=fullfile(comparisonRoot,'results',v15Folder);
[report,files]=run_leo_v15_comparison(v15Directory,v15Options,true);
run_leo_v12_show_results(v15Directory,'V15');
if ispc, winopen(v15Directory); end
