function [report,files] = run_leo_v13_comparison(directory,overrides,render)
%RUN_LEO_V13_COMPARISON 64用户/64波束/16并发，原式Tabu、SB、Local及贪婪配对。
if nargin<1, directory=fullfile('results','v13_from_v12_64users_16streams'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
if ~isfield(overrides,'parameters'), overrides.parameters=leo_v13_parameters(); end
p=overrides.parameters;
assert(p.system.K==64 && p.array.nBeams==64 && p.system.maxStreams==16, ...
    'V13 requires K=64, NB=64 and L=16 (one-quarter beam admission).');
[report,files]=run_leo_v12_comparison(directory,overrides,render,'V13');
end
