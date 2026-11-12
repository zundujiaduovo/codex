function [report,files]=run_leo_v14_comparison(directory,overrides,render)
if nargin<1, directory=fullfile('results','v14_from_v13_fairness_coordination_stage2_v2'); end
if nargin<2, [overrides,~]=V14_SETTINGS(); end
if nargin<3, render=true; end
o=leo_v13_options(overrides);
assert(isfield(o.method,'coordination'),'V14 requires normalized coordination options.');
assert(o.method.sbSteps>=o.method.coordination.sbMinSteps,'sbSteps must cover the configured minimum adaptive integration steps.');
[report,files]=run_leo_v12_comparison(directory,o,render,'V14');
if ~o.prepareOnly
    [~,extra]=run_leo_v14_targets(report,directory,render); files=[files,extra];
    run_leo_v14_evidence(report,directory);
end
end
