function [o,folder]=V15_SETTINGS()
% Includes the repaired V14 stage-2 trust paths and stall-radius expansion.
[o,~]=V14_SETTINGS();
assert(o.method.coordination.stage2TrustPaths && o.method.coordination.stage2StallExpand);
folder='v15_from_v14_repaired_search_original_bounds';
end
