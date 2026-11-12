function installation=CHECK_V14_INSTALLATION(projectRoot)
if nargin<1, projectRoot=fileparts(mfilename('fullpath')); end
required={'leo_v14_coordination_options','leo_v14_run_price_phase','leo_v14_solve_resource', ...
 'leo_v14_adaptive_sb','leo_v14_encode_qubo','leo_v14_joint_blocks','leo_v14_select_candidates', ...
 'leo_v14_coupled_bound','leo_verified_lp_upper','leo_sparse_lp_dual','leo_v14_floor_bound', ...
 'run_leo_v14_comparison','run_leo_v14_common_floor','run_leo_v14_kernel_control', ...
 'run_leo_v14_targets','run_leo_v14_evidence','leo_v14_trust_path','run_leo_v14_stage2_repair'};
matlabDirectory=fullfile(projectRoot,'matlab'); missing={};
for j=1:numel(required)
    expected=fullfile(matlabDirectory,[required{j},'.m']);
    if exist(expected,'file')~=2, missing{end+1}=expected; end %#ok<AGROW>
end
if ~isempty(missing)
    error('leo:v14MissingSource', ...
        ['V14 source files are missing from this project:\n%s\n', ...
         'Extract V14_complete_source_update.zip DIRECTLY into %s, keeping results/.\n', ...
         'The matlab/ folder must be directly under the project root.'],strjoin(missing,sprintf('\n')),projectRoot);
end
installation=CHECK_V13_INSTALLATION(projectRoot);
addpath(projectRoot,'-begin'); addpath(matlabDirectory,'-begin'); rehash;
resolved=cell(size(required));
for j=1:numel(required)
    expected=fullfile(matlabDirectory,[required{j},'.m']);
    clear(required{j}); actual=which(required{j}); resolved{j}=actual;
    if ispc, same=strcmpi(expected,actual); else, same=strcmp(expected,actual); end
    if ~same
        error('leo:v14ShadowedSource', ...
            ['V14 function resolves outside this project: %s\nExpected: %s\nActual: %s\n', ...
             'Run clear functions, change to this project root, add its matlab/ folder first, and run rehash.'], ...
            required{j},expected,actual);
    end
end
installation.v14Required=required; installation.v14Resolved=resolved;
fprintf('PASS: V14 based on V13; simplex fairness, joint blocks, gain trust, adaptive bSB and coupled upper bounds.\n');
end
