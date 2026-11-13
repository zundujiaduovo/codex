function p=leo_v17_search_options(overrides)
% Independent original-model escapes and strict lexicographic phase handoff.
p=struct('promoteFairness',true,'fairnessEscapes',4,'escapeRounds',48, ...
    'escapeCandidates',160,'escapeBlocks',3,'randomizeNeighbors',true, ...
    'calibrateTangents',true);
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(p))));
for j=1:numel(names), p.(names{j})=overrides.(names{j}); end
for name={'promoteFairness','randomizeNeighbors','calibrateTangents'}
    v=p.(name{1}); assert(isscalar(v) && any(v==[0,1])); p.(name{1})=logical(v);
end
for name={'fairnessEscapes','escapeRounds','escapeCandidates','escapeBlocks'}
    v=p.(name{1}); assert(isscalar(v) && isfinite(v) && v>=0 && v==fix(v));
end
assert(p.escapeRounds>=1 && p.escapeCandidates>=1 && p.escapeBlocks>=2);
end
