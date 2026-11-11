function installation = CHECK_V12_INSTALLATION(projectRoot)
%CHECK_V12_INSTALLATION 在计算前检查V12绘图依赖及实际解析路径；不读取/修改结果。
if nargin<1, projectRoot=fileparts(mfilename('fullpath')); end
matlabDirectory=fullfile(projectRoot,'matlab');
required={'run_leo_v12_comparison','run_leo_v12_summary','run_leo_v12_diagnostics', ...
    'leo_v12_load_report','leo_v12_diagnostic_data','leo_build_v12_diagnostic_specs', ...
    'run_leo_v12_show_results','run_leo_v12_greedy_control','run_leo_v12_proxy_control','run_leo_v12_scaling'};
missing={};
for j=1:numel(required)
    if exist(fullfile(matlabDirectory,[required{j},'.m']),'file')~=2
        missing{end+1}=[required{j},'.m']; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('leo:v12IncompleteInstallation', ...
        ['V12 source installation is incomplete. Missing from %s: %s. ', ...
         'Extract V12_complete_source_update.zip DIRECTLY into the project root (no extra outer folder). ', ...
         'Keep results/. See INSTALL_V12_UPDATE.md.'],matlabDirectory,strjoin(missing,', '));
end
addpath(matlabDirectory,'-begin'); rehash;
resolved=cell(size(required));
for j=1:numel(required)
    resolved{j}=which(required{j});
    expected=fullfile(matlabDirectory,[required{j},'.m']);
    actual=strrep(resolved{j},filesep,'/'); target=strrep(expected,filesep,'/');
    same=strcmp(actual,target); if ispc, same=strcmpi(actual,target); end
    if ~same
        error('leo:v12PathShadow', ...
            ['V12 path conflict: %s resolves to %s, expected %s. ', ...
             'Use this project root, clear functions, and remove/rename the duplicate function in the current folder. ', ...
             'Keep results/.'],required{j},resolved{j},expected);
    end
end
installation=struct('projectRoot',projectRoot,'matlabDirectory',matlabDirectory, ...
    'requiredFunctions',{required},'resolvedFiles',{resolved});
fprintf('PASS: V12 installation complete; all %d analysis functions resolve inside %s. Existing results unchanged.\n',numel(required),matlabDirectory);
end
