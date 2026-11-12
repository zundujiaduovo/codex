function [report,files]=run_leo_v15_comparison(directory,overrides,render)
if nargin<1, [~,folder]=V15_SETTINGS(); directory=fullfile('results',folder); end
if nargin<2, [overrides,~]=V15_SETTINGS(); end
if nargin<3, render=true; end
o=leo_v13_options(overrides);
assert(isfield(o.method,'coordination') && o.method.coordination.stage2TrustPaths && o.method.coordination.stage2StallExpand);
[report,files]=run_leo_v12_comparison(directory,o,render,'V15');
if ~o.prepareOnly
    [~,extra]=run_leo_v14_targets(report,directory,render); files=[files,extra];
    run_leo_v14_evidence(report,directory);
    fprintf('V15 search saved. RUN_V15_BOUNDS independently tightens the initial relaxation bounds and resumes saved certificate trees.\n');
end
end
