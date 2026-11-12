function o=leo_v15_bound_options(overrides)
% Independent original-model certificate. Limits are ADDITIONAL work per invocation.
o=struct('relativeGap',.001,'absoluteGap',1e-6,'maxSweeps',60, ...
    'maxBranchNodes',128,'pricingNodesPerCall',2000,'maxSimplexPivots',20000, ...
    'lpTolerance',1e-7,'pricingTolerance',1e-9,'roundingCandidates',4, ...
    'arithmeticGuard',1e-9,'maxSeconds',Inf,'verbose',true);
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))),'Unknown V15 certificate option.');
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
for name={'maxSweeps','maxBranchNodes','pricingNodesPerCall','maxSimplexPivots','roundingCandidates'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=1 && v==fix(v));
end
for name={'relativeGap','absoluteGap','lpTolerance','pricingTolerance','arithmeticGuard'}
    v=o.(name{1}); assert(isscalar(v) && isfinite(v) && v>=0);
end
assert(o.lpTolerance>0 && o.arithmeticGuard>=1e-12);
assert(isscalar(o.maxSeconds) && ~isnan(o.maxSeconds) && o.maxSeconds>=0);
assert(isscalar(o.verbose));
end
