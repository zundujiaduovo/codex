function yes=leo_v17_is_memory_error(err)
% MATLAB, worker-wrapped and localized out-of-memory failures.
yes=~isempty(regexpi(err.identifier,'nomem|outofmemory|(^|:)oom($|:)','once')) || ...
    ~isempty(regexpi(err.message,'内存不足|out[_ ]of[_ ]memory|insufficient memory|cannot allocate memory|not enough memory','once'));
if yes, return; end
for j=1:numel(err.cause)
    if leo_v17_is_memory_error(err.cause{j}), yes=true; return; end
end
end
