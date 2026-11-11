function directory = leo_v13_saved_directory(root,preferDiagnosis)
%LEO_V13_SAVED_DIRECTORY 按新配置、旧自适应、旧固定预算顺序找实际保存的数据。
if nargin<2, preferDiagnosis=false; end
[~,name]=V13_SETTINGS();
names={name,'v13_64users_128ant_iterations','v13_64users_scaled_audit','v13_from_v12_64users_16streams_adaptive','v13_from_v12_64users_16streams'};
for j=1:numel(names)
    directory=fullfile(root,'results',names{j});
    if exist(fullfile(directory,'benchmark.mat'),'file')~=2, continue; end
    if preferDiagnosis && exist(fullfile(directory,'diagnosis','benchmark.mat'),'file')==2
        directory=fullfile(directory,'diagnosis');
    end
    return;
end
error('leo:noV13Result','No saved V13 benchmark found under %s.',fullfile(root,'results'));
end
