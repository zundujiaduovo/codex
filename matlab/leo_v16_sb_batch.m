function r=leo_v16_sb_batch(q,o,seeds,seed,kernel)
% A worker owns a reproducible random stream for this fixed-index batch.
previous=rng; cleanup=onCleanup(@()rng(previous)); rng(seed,'twister'); %#ok<NASGU>
if strcmp(kernel,'adaptive'), r=leo_v14_adaptive_sb(q,o,seeds,[]);
else
    r=leo_v8_ballistic_sb(leo_qubo_to_ising(q),o,seeds,[]);
    r.trajectorySteps=r.steps*o.sbTrajectories; r.denseTerms=q.nBits^2*r.trajectorySteps; r.restarts=0;
end
r.workerExecuted=false;
if exist('getCurrentTask','file')>0, r.workerExecuted=~isempty(getCurrentTask()); end
end
