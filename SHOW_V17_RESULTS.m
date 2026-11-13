clear functions
root=fileparts(mfilename('fullpath')); CHECK_V17_INSTALLATION(root);
[~,folder]=V17_SETTINGS(); directory=fullfile(root,'results',folder);
run_leo_v12_show_results(directory,'V17');
figures=dir(fullfile(directory,'original_certificates','**','*.fig'));
for j=1:numel(figures), openfig(fullfile(figures(j).folder,figures(j).name),'new','visible'); end
