function p=leo_v17_memory_options(overrides)
% Bound detailed diagnostics; retain the scalar history needed for convergence plots.
p=struct('retainStateHistory',false,'maxEvidenceRows',2000,'revision',1);
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(p))));
for j=1:numel(names), p.(names{j})=overrides.(names{j}); end
v=p.retainStateHistory; assert(isscalar(v) && any(v==[0,1])); p.retainStateHistory=logical(v);
for name={'maxEvidenceRows','revision'}
    v=p.(name{1}); assert(isscalar(v) && isfinite(v) && v>=1 && v==fix(v));
end
end
