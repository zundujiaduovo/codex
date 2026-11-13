function s=V17_BOUND_SETTINGS()
% Independent original-model certification; rerunning resumes existing trees.
s.fairness=leo_v15_bound_options();
s.throughput=leo_v15_bound_options(struct('maxSweeps',20,'maxBranchNodes',64));
s.conditionalThroughput=true;
s.sourceDirectory='';
end
