clear functions
comparisonRoot=fileparts(mfilename('fullpath')); CHECK_V15_INSTALLATION(comparisonRoot);
[~,v15Folder]=V15_SETTINGS(); v15Directory=fullfile(comparisonRoot,'results',v15Folder);
v15BoundSettings=V15_BOUND_SETTINGS();
if ~isempty(v15BoundSettings.sourceDirectory), v15Directory=v15BoundSettings.sourceDirectory; end
v15SourceReport=leo_v12_load_report(v15Directory); v15SourceRelease=leo_lexicographic_release(v15SourceReport);
run_leo_v12_show_results(v15Directory,v15SourceRelease.tag);
v15BoundDirectory=fullfile(v15Directory,'v15_original_certificates');
v15Figures=dir(fullfile(v15BoundDirectory,'**','*.fig'));
for j=1:numel(v15Figures), openfig(fullfile(v15Figures(j).folder,v15Figures(j).name),'new','visible'); end
