function o = leo_v13_options(overrides)
%LEO_V13_OPTIONS V13默认启用提前停止；120秒为每方法最长保护预算。
if nargin<1, overrides=struct(); end
if ~isfield(overrides,'parameters'), overrides.parameters=leo_v13_parameters(); end
if ~isfield(overrides,'method'), overrides.method=struct(); end
defaults=struct('sbSteps',500,'sbTrajectories',32,'localRestarts',32,'polishMoves',12,'refreshEvery',2,'fastPolish',true);
names=fieldnames(defaults);
for j=1:numel(names), if ~isfield(overrides.method,names{j}), overrides.method.(names{j})=defaults.(names{j}); end; end
if ~isfield(overrides.method,'audit'), overrides.method.audit=struct('enabled',true); end
if ~isfield(overrides.method,'stopping'), overrides.method.stopping=struct(); end
if ~isfield(overrides.method.stopping,'enabled'), overrides.method.stopping.enabled=true; end
if ~isfield(overrides.method.stopping,'patienceSeconds'), overrides.method.stopping.patienceSeconds=40; end
if ~isfield(overrides.method.stopping,'minIterations'), overrides.method.stopping.minIterations=6; end
if ~isfield(overrides,'fairnessCertificateOptions'), overrides.fairnessCertificateOptions=struct(); end
if ~isfield(overrides.fairnessCertificateOptions,'relaxationMaxSeconds'), overrides.fairnessCertificateOptions.relaxationMaxSeconds=60; end
if ~isfield(overrides.fairnessCertificateOptions,'relaxationMaxIterations'), overrides.fairnessCertificateOptions.relaxationMaxIterations=300; end
o=leo_v12_options(overrides); p=o.parameters;
assert(p.system.K==64 && p.array.nBeams==64 && p.system.maxStreams==16, ...
    'V13 requires K=64, NB=64 and L=16 (one-quarter beam admission).');
end
