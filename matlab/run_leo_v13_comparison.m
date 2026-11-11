function [report,files] = run_leo_v13_comparison(directory,overrides,render)
%RUN_LEO_V13_COMPARISON 64用户/64波束/16并发，原式Tabu、SB、Local及贪婪配对。
if nargin<1, directory=fullfile('results','v13_64users_scaled_audit'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
o=leo_v13_options(overrides);
[report,files]=run_leo_v12_comparison(directory,o,render,'V13');
if ~o.prepareOnly && isfield(o.method,'audit') && o.method.audit.enabled
    [~,auditFiles]=run_leo_v13_candidate_audit(directory,struct(),render); files=[files,auditFiles];
end
end
