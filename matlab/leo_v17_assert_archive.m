function leo_v17_assert_archive(result)
% Fail loudly if any saved lexicographically better solution was later discarded.
o=result.options;
if ~isfield(o,'searchPolicy') || ~o.searchPolicy.promoteFairness, return; end
if isfield(o,'coordination') && isfinite(o.coordination.stage2Floor), return; end
fairness=[]; total=[];
for phase=1:2
    h=result.(sprintf('stage%d',phase)).history;
    fairness=[fairness,h.savedFairness]; total=[total,h.savedTotalBits]; %#ok<AGROW>
end
assert(result.service.fairness>=max(fairness),'leo:v17FairnessRegression', ...
    'Final fairness is below a previously saved value.');
same=fairness==result.service.fairness;
assert(all(total(same)<=result.service.totalBits),'leo:v17LexicographicRegression', ...
    'A better saved sum at the same fairness was discarded.');
assert(all(result.service.demandRatio>=result.fairnessFloor),'leo:v17FloorRegression', ...
    'The final schedule violates the attained fairness floor.');
end
