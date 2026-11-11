function o = leo_v13_options(overrides)
%LEO_V13_OPTIONS 64用户/128阵元/64波束/16并发，默认只受迭代次数限制。
if nargin<1, overrides=struct(); end
if ~isfield(overrides,'parameters'), overrides.parameters=leo_v13_parameters(); end
if ~isfield(overrides,'method'), overrides.method=struct(); end
defaults=struct('sbSteps',500,'sbTrajectories',32,'localRestarts',32,'polishMoves',12, ...
    'refreshEvery',2,'fastPolish',true,'iterationOnly',true,'fairnessRounds',60, ...
    'throughputRounds',30,'proxyTabuIterations',80,'proxyTabuRestarts',4,'proxyTabuTenure',7);
originalCap=2000;
if isfield(overrides.method,'originalSearchRounds'), originalCap=overrides.method.originalSearchRounds; end
defaults.originalFairnessRounds=originalCap;
defaults.originalThroughputRounds=min(1000,originalCap);
names=fieldnames(defaults);
for j=1:numel(names), if ~isfield(overrides.method,names{j}), overrides.method.(names{j})=defaults.(names{j}); end; end
if ~isfield(overrides.method,'audit'), overrides.method.audit=struct('enabled',true); end
if ~isfield(overrides.method,'stopping'), overrides.method.stopping=struct(); end
if ~isfield(overrides.method.stopping,'enabled'), overrides.method.stopping.enabled=false; end
if ~isfield(overrides.method.stopping,'patienceSeconds'), overrides.method.stopping.patienceSeconds=40; end
if ~isfield(overrides.method.stopping,'minIterations'), overrides.method.stopping.minIterations=6; end
if ~isfield(overrides,'fairnessCertificateOptions'), overrides.fairnessCertificateOptions=struct(); end
if ~isfield(overrides.fairnessCertificateOptions,'relaxationMaxSeconds'), overrides.fairnessCertificateOptions.relaxationMaxSeconds=Inf; end
if ~isfield(overrides.fairnessCertificateOptions,'relaxationMaxIterations'), overrides.fairnessCertificateOptions.relaxationMaxIterations=300; end
if leo_iteration_only(overrides.method)
    overrides.budgetSeconds=Inf;
    overrides.method.stopping.enabled=false;
    overrides.fairnessCertificateOptions.maxSeconds=Inf;
    overrides.fairnessCertificateOptions.relaxationMaxSeconds=Inf;
    overrides.fairnessCertificateOptions.recoverySeconds=0;
    if ~isfield(overrides,'throughputCertificateOptions'), overrides.throughputCertificateOptions=struct(); end
    overrides.throughputCertificateOptions.maxSeconds=Inf;
    overrides.throughputCertificateOptions.recoverySeconds=0;
end
o=leo_v12_options(overrides); p=o.parameters;
assert(p.system.K==64 && p.array.nElements==128 && p.array.nBeams==64 && p.system.maxStreams==16, ...
    'V13 requires K=64, Na=128, NB=64 and L=16 (one-quarter beam admission).');
end
