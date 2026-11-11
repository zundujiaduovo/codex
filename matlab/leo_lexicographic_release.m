function release = leo_lexicographic_release(tag)
%LEO_LEXICOGRAPHIC_RELEASE 版本元数据；V13仅扩大场景，沿用V12求解引擎和目标。
if nargin<1, tag='V12'; end
if isstruct(tag)
    if isfield(tag,'releaseTag'), tag=tag.releaseTag; else, tag='V12'; end
end
switch tag
    case {'V12','V12 uncapped lexicographic'}
        release=struct('tag','V12','version','V12 uncapped lexicographic', ...
            'baseCommit','37bbe3d72cbb13b26fa1e6a5384391afddd64020', ...
            'caseName','v12_uncapped_lexicographic', ...
            'methods',{{'original_tabu','sb_v12_lexicographic','local_v12_lexicographic'}});
    case {'V13','V13 based on V12: 64 users, 64 beams, 16 streams'}
        release=struct('tag','V13','version','V13 based on V12: 64 users, 64 beams, 16 streams', ...
            'baseCommit','3a004695eb6f2ad90fe8be9b6b05de6e2017d6bc', ...
            'caseName','v13_from_v12_64users_16streams', ...
            'methods',{{'Tabu','SB','Local','Greedy'}});
    otherwise
        error('leo:lexicographicVersion','Unsupported experiment version: %s.',tag);
end
release.prefix=lower(release.tag);
end
