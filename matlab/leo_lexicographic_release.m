function r=leo_lexicographic_release(tag)
% V16 has one current protocol; archived versions remain in their Git branches.
if nargin<1, tag='V16'; end
if isstruct(tag), tag=tag.releaseTag; end
assert(any(strcmp(tag,{'V16','V16 parallel64; original-objective convergence; based on repaired V15'})), ...
    'Use the original branch to read historical protocols, or point the standalone bound function at saved data.');
r=struct('tag','V16','version','V16 parallel64; original-objective convergence; based on repaired V15', ...
    'baseCommit','97afd6c','caseName','v16_parallel64_until_convergence', ...
    'methods',{{'Tabu','SB','Local','Proxy+Tabu','Greedy'}},'prefix','v16');
end
