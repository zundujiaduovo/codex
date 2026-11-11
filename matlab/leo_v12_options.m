function o = leo_v12_options(overrides)
%LEO_V12_OPTIONS 新目标独立协议；默认一个种子，可显式传多种子重复。
base=leo_benchmark_options();
o=struct('sceneSeed',71669974,'seeds',71669974,'budgetSeconds',120, ...
    'validationSamples',1000,'validationSeed',71774703,'prepareOnly',false, ...
    'method',base.method,'parameters',leo_v12_parameters(), ...
    'fairnessCertificateOptions',struct('maxSeconds',180,'relativeGap',1e-5,'absoluteGap',1e-6), ...
    'throughputCertificateOptions',struct('maxSeconds',30,'relativeGap',1e-4));
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))),'Unknown V12 option; use fairnessCertificateOptions/throughputCertificateOptions for the two distinct bounds.');
for j=1:numel(names)
    name=names{j};
    if any(strcmp(name,{'method','fairnessCertificateOptions','throughputCertificateOptions'}))
        fields=fieldnames(overrides.(name));
        for k=1:numel(fields), o.(name).(fields{k})=overrides.(name).(fields{k}); end
    else, o.(name)=overrides.(name); end
end
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds)); o.seeds=double(o.seeds(:).');
assert(all(isfinite(o.seeds) & o.seeds>=0 & o.seeds<=2^32-1 & o.seeds==fix(o.seeds)) && numel(unique(o.seeds))==numel(o.seeds));
for name={'sceneSeed','validationSeed'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=0 && v<=2^32-1 && v==fix(v));
end
assert(isscalar(o.budgetSeconds) && isfinite(o.budgetSeconds) && o.budgetSeconds>0);
assert(isscalar(o.validationSamples) && isfinite(o.validationSamples) && o.validationSamples>=0 && o.validationSamples==fix(o.validationSamples));
assert(isscalar(o.prepareOnly) && any(o.prepareOnly==[0,1])); o.prepareOnly=logical(o.prepareOnly);
o.method=leo_method_options(o.method); o.parameters.seed=o.sceneSeed;
o.parameters=leo_validate_parameters(o.parameters);
assert(strcmp(o.parameters.problem.objectiveMode,'lexicographic_max_min'),'V12 requires the uncapped lexicographic objective.');
end
