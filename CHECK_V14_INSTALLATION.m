function installation=CHECK_V14_INSTALLATION(projectRoot)
if nargin<1, projectRoot=fileparts(mfilename('fullpath')); end
installation=CHECK_V13_INSTALLATION(projectRoot);
required={'leo_v14_coordination_options','leo_v14_run_price_phase','leo_v14_solve_resource', ...
 'leo_v14_adaptive_sb','leo_v14_encode_qubo','leo_v14_joint_blocks','leo_v14_select_candidates', ...
 'leo_v14_coupled_bound','leo_verified_lp_upper','leo_sparse_lp_dual','leo_v14_floor_bound', ...
 'run_leo_v14_comparison','run_leo_v14_common_floor','run_leo_v14_kernel_control', ...
 'run_leo_v14_targets','run_leo_v14_evidence','leo_v14_trust_path','run_leo_v14_stage2_repair'};
for j=1:numel(required)
    expected=fullfile(projectRoot,'matlab',[required{j},'.m']); actual=which(required{j});
    if ispc, same=strcmpi(expected,actual); else, same=strcmp(expected,actual); end
    assert(same,['V14 missing/shadowed function: ',required{j},'. Extract the complete V14 source package.']);
end
fprintf('PASS: V14 based on V13; simplex fairness, joint blocks, gain trust, adaptive bSB and coupled upper bounds.\n');
end
