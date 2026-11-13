function rule=leo_v17_accept_phase(phase,o)
% Fixed-floor controls intentionally retain their throughput-only objective.
rule=phase;
if strcmp(phase,'throughput') && isfield(o,'searchPolicy') && o.searchPolicy.promoteFairness
    fixed=false;
    if isfield(o,'coordination'), fixed=isfinite(o.coordination.stage2Floor); end
    if ~fixed, rule='fairness'; end % compare (original fairness, original sum)
end
end
