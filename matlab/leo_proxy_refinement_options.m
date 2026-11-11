function r=leo_proxy_refinement_options(overrides)
% 可分别关闭的代理刷新、候选池及瓶颈候选；历史调用默认全关闭。
r=struct('candidatePool',false,'bottleneckCandidates',false,'candidateRefresh',false, ...
    'poolSize',8,'bottleneckBand',.03,'gapTrigger',.01);
if nargin>0
    names=fieldnames(overrides); assert(all(ismember(names,fieldnames(r))));
    for j=1:numel(names), r.(names{j})=overrides.(names{j}); end
end
for name={'candidatePool','bottleneckCandidates','candidateRefresh'}
    v=r.(name{1}); assert(isscalar(v) && any(v==[0,1])); r.(name{1})=logical(v);
end
assert(isscalar(r.poolSize) && isfinite(r.poolSize) && r.poolSize>=2 && r.poolSize==fix(r.poolSize));
assert(isscalar(r.bottleneckBand) && isfinite(r.bottleneckBand) && r.bottleneckBand>0);
assert(isscalar(r.gapTrigger) && isfinite(r.gapTrigger) && r.gapTrigger>=0);
end
