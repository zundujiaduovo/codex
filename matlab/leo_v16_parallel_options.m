function p=leo_v16_parallel_options(overrides)
% Actual independent SB batches on a MATLAB process pool. No silent serial fallback.
p=struct('enabled',false,'workers',0,'batchSize',8);
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(p))));
for j=1:numel(names), p.(names{j})=overrides.(names{j}); end
assert(isscalar(p.enabled) && any(p.enabled==[0,1])); p.enabled=logical(p.enabled);
assert(isscalar(p.workers) && isfinite(p.workers) && p.workers>=0 && p.workers==fix(p.workers));
assert(isscalar(p.batchSize) && isfinite(p.batchSize) && p.batchSize>=1 && p.batchSize==fix(p.batchSize));
end
