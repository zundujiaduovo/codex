clear functions
root=fileparts(mfilename('fullpath')); CHECK_V17_INSTALLATION(root);
[~,folder]=V17_SETTINGS(); settings=V17_BOUND_SETTINGS(); source=fullfile(root,'results',folder);
if ~isempty(settings.sourceDirectory), source=settings.sourceDirectory; end
assert(exist(fullfile(source,'benchmark.mat'),'file')==2,'Run RUN_COMPARISON first or set sourceDirectory.');
[certifiedReport,files]=run_leo_v15_bounds(source,fullfile(source,'original_certificates'),settings,true);
if ispc, winopen(fullfile(source,'original_certificates')); end
