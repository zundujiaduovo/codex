function r=leo_lexicographic_release(tag)
% One current protocol; historical experiments remain on their original branches.
if nargin<1, tag='V17'; end
if isstruct(tag), tag=tag.releaseTag; end
version='V17 fairness-first archive, calibrated proxy, parallel64 bSB; based on V16';
assert(any(strcmp(tag,{'V17',version})), 'Use the original branch for historical protocols.');
r=struct('tag','V17','version',version,'baseCommit','4b5ea77', ...
    'caseName','v17_gpu64_memory_safe', ...
    'methods',{{'Tabu','SB','Local','Proxy+Tabu','Greedy'}},'prefix','v17');
end
