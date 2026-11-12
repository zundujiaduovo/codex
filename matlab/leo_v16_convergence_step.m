function [s,done]=leo_v16_convergence_step(o,phase,service,iteration,s,family)
% Full nonoverlapping windows test cumulative ORIGINAL objective improvement.
if nargin<6, family='proxy'; end
c=leo_v16_convergence_options(); if isfield(o,'convergence'), c=leo_v16_convergence_options(o.convergence); end
value=service.fairness; if strcmp(phase,'throughput'), value=service.normalizedThroughput; end
assert(isfinite(value));
if nargin<5 || isempty(s)
    prefix='Proxy'; if strcmp(family,'original'), prefix='Original'; end
    suffix='FairnessRounds'; if strcmp(phase,'throughput'), suffix='ThroughputRounds'; end
    s=struct('options',c,'phase',phase,'family',family,'minimumRounds',c.(['min',prefix,suffix]), ...
        'windowAnchor',value,'windowStart',iteration,'stableWindows',0,'lastWindowGain',NaN, ...
        'lastWindowTolerance',NaN,'iterations',iteration,'heuristicConverged',false, ...
        'scope','Empirical ORIGINAL-objective plateau only; global optimality requires the independent certificate.');
end
s.iterations=iteration;
if iteration-s.windowStart>=c.windowRounds
    gain=value-s.windowAnchor; tolerance=max(c.absoluteTolerance,c.relativeTolerance*max(abs(s.windowAnchor),eps));
    assert(gain>=-1e-8*max(1,abs(value)),'Saved phase objective must be nondecreasing.');
    if gain<=tolerance, s.stableWindows=s.stableWindows+1; else, s.stableWindows=0; end
    s.lastWindowGain=gain; s.lastWindowTolerance=tolerance; s.windowAnchor=value; s.windowStart=iteration;
end
done=c.enabled && iteration>=s.minimumRounds && s.stableWindows>=c.stableWindows;
s.heuristicConverged=done;
end
