function o = leo_stopping_options(overrides)
%LEO_STOPPING_OPTIONS 可选提前停止；近优证书与启发式停滞分别标记。
o=struct('enabled',false,'relativeGap',.01,'minPhaseSeconds',10, ...
    'patienceSeconds',20,'relativeImprovement',1e-4,'minIterations',3);
if nargin>0
    assert(isstruct(overrides) && isscalar(overrides));
    names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))),'Unknown stopping option.');
    for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
end
v=o.enabled; assert(isscalar(v) && (islogical(v) || isnumeric(v)) && isfinite(v) && any(v==[0,1]));
o.enabled=logical(v);
for name={'relativeGap','minPhaseSeconds','patienceSeconds','relativeImprovement','minIterations'}
    v=o.(name{1}); assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v) && v>=0);
end
assert(o.relativeGap<1 && o.relativeImprovement<1 && o.patienceSeconds>0);
assert(o.minIterations>=1 && o.minIterations==fix(o.minIterations));
end
