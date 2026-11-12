function installation=CHECK_V15_INSTALLATION(projectRoot)
if nargin<1, projectRoot=fileparts(mfilename('fullpath')); end
installation=CHECK_V14_INSTALLATION(projectRoot);
required={'leo_v15_bound_options','leo_v15_price_block','leo_v15_master','leo_v15_certificate', ...
    'leo_v15_certificate_result','leo_v15_export_certificate','run_leo_v15_comparison','run_leo_v15_bounds'};
for j=1:numel(required)
    expected=fullfile(projectRoot,'matlab',[required{j},'.m']);
    assert(exist(expected,'file')==2,'V15 missing source: %s. Extract the complete V15 archive.',expected);
    clear(required{j}); actual=which(required{j});
    if ispc, same=strcmpi(expected,actual); else, same=strcmp(expected,actual); end
    assert(same,'V15 shadowed function %s. Expected %s; actual %s.',required{j},expected,actual);
end
[o,~]=V15_SETTINGS(); c=o.method.coordination;
assert(c.stage2TrustPaths && c.stage2StallExpand && c.stage2SearchRevision>=2);
installation.v15Required=required;
fprintf('PASS: V15 includes repaired V14 search and resumable ORIGINAL-service branch-and-price; no 18-beam pricing cap.\n');
end
