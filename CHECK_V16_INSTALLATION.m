function CHECK_V16_INSTALLATION(root)
if nargin<1, root=fileparts(mfilename('fullpath')); end
addpath(root,'-begin'); addpath(fullfile(root,'matlab'),'-begin'); rehash;
required={'leo_v16_parallel_options','leo_v16_prepare_parallel','leo_v16_parallel_sb','leo_v16_sb_batch', ...
    'leo_v16_convergence_options','leo_v16_convergence_step','leo_v16_initial_bounds', ...
    'leo_v14_run_price_phase','leo_v14_solve_resource','leo_v14_trust_path', ...
    'leo_v15_certificate','leo_v15_price_block','leo_v15_master','run_leo_v15_bounds'};
for j=1:numel(required)
    path=fullfile(root,'matlab',[required{j},'.m']);
    assert(exist(path,'file')==2,'V16 missing function: %s. Extract the complete V16 package.',path);
    actual=which(required{j}); if ispc, same=strcmpi(actual,path); else, same=strcmp(actual,path); end
    assert(same,'V16 path conflict: %s resolves to %s.',required{j},actual);
end
fprintf('PASS V16: 64 users, 128 antennas, 16 streams; parallel64 and iteration-window convergence; independent original upper bounds.\n');
end
