function [state,status] = leo_search_stopping(options,phase,service,upper,seconds,iteration,state)
%LEO_SEARCH_STOPPING 只看原目标：有效界差距达标或累计改进长期低于阈值。
% 显式seconds便于用确定性时钟验证；停滞永远不标为已认证近优。
value=service.fairness; if strcmp(phase,'throughput'), value=service.normalizedThroughput; end
if nargin<7 || isempty(state)
    stop=leo_stopping_options(); if isfield(options,'stopping'), stop=leo_stopping_options(options.stopping); end
    state=struct('options',stop,'phase',phase,'startSeconds',seconds, ...
        'lastImprovementSeconds',seconds,'anchorValue',value,'absoluteTolerance',options.gapTolerance);
end
assert(upper>=value-1e-10*max(1,abs(value)),'Original-model upper bound is below the saved feasible value.');
if value-state.anchorValue>max(state.absoluteTolerance, ...
        state.options.relativeImprovement*max(abs(state.anchorValue),eps))
    state.anchorValue=value; state.lastImprovementSeconds=seconds;
end
state.upper=upper; state.lower=value; state.absoluteGap=max(0,upper-value);
state.relativeGap=Inf;
if isfinite(upper), state.relativeGap=state.absoluteGap/max(abs(upper),eps); end
state.phaseSeconds=seconds-state.startSeconds;
state.stagnantSeconds=seconds-state.lastImprovementSeconds;
state.iterations=iteration;
state.nearOptimalCertified=isfinite(upper) && ...
    state.absoluteGap<=max(state.absoluteTolerance,state.options.relativeGap*abs(upper));
status='';
if ~state.options.enabled, return; end
if state.nearOptimalCertified
    status='target_gap';
elseif iteration>=state.options.minIterations && state.phaseSeconds>=state.options.minPhaseSeconds && ...
        state.stagnantSeconds>=state.options.patienceSeconds
    status='stagnation';
end
end
