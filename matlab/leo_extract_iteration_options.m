function [remaining,extra] = leo_extract_iteration_options(overrides)
%LEO_EXTRACT_ITERATION_OPTIONS 保持历史冻结参数校验器不变。
remaining=overrides; extra=struct();
names={'iterationOnly','originalFairnessRounds','originalThroughputRounds', ...
    'proxyTabuIterations','proxyTabuRestarts','proxyTabuTenure','refinement'};
for j=1:numel(names)
    name=names{j}; if ~isfield(remaining,name), continue; end
    value=remaining.(name);
    if strcmp(name,'refinement')
        value=leo_proxy_refinement_options(value);
    elseif strcmp(name,'iterationOnly')
        assert(isscalar(value) && any(value==[0,1])); value=logical(value);
    else
        assert(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value>=1 && value==fix(value));
    end
    extra.(name)=value; remaining=rmfield(remaining,name);
end
end
