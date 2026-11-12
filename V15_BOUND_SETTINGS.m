function settings=V15_BOUND_SETTINGS()
% Limits below are ADDITIONAL certificate work each time RUN_V15_BOUNDS is run.
% Increasing work limits resumes existing trees. Changing model/floor starts a
% different certificate. A work limit is never reported as an accuracy proof.
settings.fairness=leo_v15_bound_options();  % target gap 0.1%, 60 pricing sweeps
settings.throughput=leo_v15_bound_options(struct('maxSweeps',20,'maxBranchNodes',64));
settings.conditionalThroughput=true;
settings.sourceDirectory=''; % Optional absolute path to an existing V14/V15 result folder.
end
