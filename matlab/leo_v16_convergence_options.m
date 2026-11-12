function c=leo_v16_convergence_options(overrides)
% Iteration-based empirical convergence, independent of time and global bounds.
c=struct('enabled',false,'windowRounds',100,'stableWindows',3, ...
    'relativeTolerance',1e-6,'absoluteTolerance',1e-8, ...
    'minProxyFairnessRounds',240,'minProxyThroughputRounds',120, ...
    'minOriginalFairnessRounds',2000,'minOriginalThroughputRounds',1000);
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(c))));
for j=1:numel(names), c.(names{j})=overrides.(names{j}); end
assert(isscalar(c.enabled) && any(c.enabled==[0,1])); c.enabled=logical(c.enabled);
for name={'windowRounds','stableWindows','minProxyFairnessRounds','minProxyThroughputRounds','minOriginalFairnessRounds','minOriginalThroughputRounds'}
    v=c.(name{1}); assert(isscalar(v) && isfinite(v) && v>=1 && v==fix(v));
end
assert(c.relativeTolerance>=0 && c.relativeTolerance<1 && isfinite(c.relativeTolerance));
assert(c.absoluteTolerance>=0 && isfinite(c.absoluteTolerance));
end
