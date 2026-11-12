% Certificate only: never reruns benchmark search. Repeating resumes open trees.
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V15_INSTALLATION(comparisonRoot);
v15BoundSettings=V15_BOUND_SETTINGS(); [~,v15Folder]=V15_SETTINGS();
v15Source=fullfile(comparisonRoot,'results',v15Folder);
if ~isempty(v15BoundSettings.sourceDirectory), v15Source=v15BoundSettings.sourceDirectory; end
assert(exist(fullfile(v15Source,'benchmark.mat'),'file')==2, ...
    'Run RUN_V15_COMPARISON first, or set sourceDirectory in V15_BOUND_SETTINGS to a saved V14/V15 result folder.');
v15BoundDirectory=fullfile(v15Source,'v15_original_certificates');
[certifiedReport,certificateFiles]=run_leo_v15_bounds(v15Source,v15BoundDirectory,v15BoundSettings,true);
if ispc, winopen(v15BoundDirectory); end
