function yes = leo_iteration_only(options)
%LEO_ITERATION_ONLY 迭代次数模式只计时，不按耗时或停滞终止。
yes=isfield(options,'iterationOnly') && logical(options.iterationOnly);
end
