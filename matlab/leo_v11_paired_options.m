function o = leo_v11_paired_options(overrides)
%LEO_V11_PAIRED_OPTIONS V11基于V10的预先固定配对协议；不修改搜索参数。
base=leo_benchmark_options();
o=struct('sceneSeed',71669974,'seeds',71669974+104729*(0:19), ...
    'budgetSeconds',120,'validationSamples',1000,'validationSeed',71774703, ...
    'bootstrapSamples',10000,'bootstrapSeed',20261111,'tieToleranceBits',1, ...
    'prepareOnly',false,'method',base.method, ...
    'theoryOptions',struct('maxSeconds',600,'maxNodes',1024,'maxIterations',500, ...
        'maxSimplexPivots',30000,'relativeGap',1e-5));
if nargin<1, overrides=struct(); end
assert(isstruct(overrides) && isscalar(overrides));
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))),'Unknown V11 paired option.');
for j=1:numel(names)
    name=names{j};
    if any(strcmp(name,{'method','theoryOptions'}))
        fields=fieldnames(overrides.(name));
        for k=1:numel(fields), o.(name).(fields{k})=overrides.(name).(fields{k}); end
    else
        o.(name)=overrides.(name);
    end
end
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds));
o.seeds=double(o.seeds(:).');
assert(all(isfinite(o.seeds) & o.seeds>=0 & o.seeds<=2^32-1 & o.seeds==fix(o.seeds)));
assert(numel(unique(o.seeds))==numel(o.seeds),'Search seeds must be unique.');
for name={'sceneSeed','validationSeed','bootstrapSeed'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=0 && v<=2^32-1 && v==fix(v));
end
assert(isscalar(o.budgetSeconds) && isfinite(o.budgetSeconds) && o.budgetSeconds>0);
assert(isscalar(o.validationSamples) && isfinite(o.validationSamples) && o.validationSamples>=0 && o.validationSamples==fix(o.validationSamples));
assert(isscalar(o.bootstrapSamples) && isfinite(o.bootstrapSamples) && o.bootstrapSamples>=100 && o.bootstrapSamples==fix(o.bootstrapSamples));
assert(isscalar(o.tieToleranceBits) && isfinite(o.tieToleranceBits) && o.tieToleranceBits>=0);
assert(isscalar(o.prepareOnly) && any(o.prepareOnly==[0,1]));
o.prepareOnly=logical(o.prepareOnly); o.method=leo_method_options(o.method);
end
