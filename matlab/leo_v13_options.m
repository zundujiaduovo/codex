function o = leo_v13_options(overrides)
%LEO_V13_OPTIONS V13默认启用提前停止；120秒为每方法最长保护预算。
if nargin<1, overrides=struct(); end
if ~isfield(overrides,'parameters'), overrides.parameters=leo_v13_parameters(); end
if ~isfield(overrides,'method'), overrides.method=struct(); end
if ~isfield(overrides.method,'stopping'), overrides.method.stopping=struct(); end
if ~isfield(overrides.method.stopping,'enabled'), overrides.method.stopping.enabled=true; end
o=leo_v12_options(overrides); p=o.parameters;
assert(p.system.K==64 && p.array.nBeams==64 && p.system.maxStreams==16, ...
    'V13 requires K=64, NB=64 and L=16 (one-quarter beam admission).');
end
