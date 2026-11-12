clear functions
root=fileparts(mfilename('fullpath')); CHECK_V16_INSTALLATION(root);
[~,folder]=V16_SETTINGS(); directory=fullfile(root,'results',folder);
run_leo_v12_show_results(directory,'V16');
figures=dir(fullfile(directory,'original_certificates','**','*.fig'));
for j=1:numel(figures), openfig(fullfile(figures(j).folder,figures(j).name),'new','visible'); end
