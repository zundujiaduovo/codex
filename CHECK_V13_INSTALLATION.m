function installation = CHECK_V13_INSTALLATION(projectRoot)
%CHECK_V13_INSTALLATION 检查V13入口及继承的V12分析依赖，避免混用版本路径。
if nargin<1, projectRoot=fileparts(mfilename('fullpath')); end
matlabDirectory=fullfile(projectRoot,'matlab');
required={'leo_v13_parameters','leo_reference_users_64','leo_lexicographic_release', ...
    'run_leo_v13_comparison','run_leo_v12_comparison','run_leo_v12_pair', ...
    'run_leo_v12_summary','run_leo_v12_diagnostics','leo_v12_load_report', ...
    'leo_v12_diagnostic_data','leo_build_v12_specs','leo_build_v12_diagnostic_specs', ...
    'run_leo_v12_show_results','leo_v13_options','leo_v12_method_options', ...
    'leo_stopping_options','leo_search_stopping','leo_stopping_rows', ...
    'leo_method_id','leo_method_name','run_leo_v13_replot'};
if exist(fullfile(projectRoot,'V13_SETTINGS.m'),'file')~=2
    error('leo:v13IncompleteInstallation','Missing V13_SETTINGS.m. Extract the complete V13 source archive.');
end
for j=1:numel(required)
    expected=fullfile(matlabDirectory,[required{j},'.m']);
    if exist(expected,'file')~=2
        error('leo:v13IncompleteInstallation', ...
            'Missing %s. Extract the complete V13 source archive and run from its project root.',expected);
    end
end
addpath(projectRoot,'-begin'); addpath(matlabDirectory,'-begin'); rehash;
resolved=cell(size(required));
for j=1:numel(required)
    resolved{j}=which(required{j}); expected=fullfile(matlabDirectory,[required{j},'.m']);
    same=strcmp(resolved{j},expected); if ispc, same=strcmpi(resolved{j},expected); end
    if ~same
        error('leo:v13PathShadow','%s resolves to %s; expected %s.',required{j},resolved{j},expected);
    end
end
installation=struct('projectRoot',projectRoot,'requiredFunctions',{required},'resolvedFiles',{resolved});
fprintf('PASS: V13 installation complete; K=64, NB=64, L=16 profile and analysis dependencies resolve locally.\n');
end
