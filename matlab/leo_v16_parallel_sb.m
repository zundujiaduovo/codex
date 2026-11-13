function r=leo_v16_parallel_sb(q,o,seeds,kernel,useWorkers)
% Fixed batch partition and explicit task seeds: scheduling cannot change RNG.
% useWorkers=false executes exactly the same tasks serially for equivalence tests.
if nargin<5, useWorkers=true; end
p=leo_v16_parallel_options(o.parallel); R=o.sbTrajectories;
workers=0; backend='serial_reference_tasks';
if useWorkers
    if exist('gcp','file')==0, leo_v16_prepare_parallel(p); end
    pool=gcp('nocreate');
    if isempty(pool), runtime=leo_v16_prepare_parallel(p); workers=runtime.workers; backend=runtime.backend;
    else, workers=pool.NumWorkers; backend=class(pool); end
    assert(workers>=2,'V17 parallel mode needs two or more workers.');
end
count=ceil(R/p.batchSize); taskOptions=cell(1,count); taskSeeds=cell(1,count); ranges=cell(1,count);
randomSeeds=randi(2^31-1,1,count); answers=cell(1,count);
for b=1:count
    ids=(b-1)*p.batchSize+1:min(b*p.batchSize,R); ranges{b}=ids;
    local=o; local.sbTrajectories=numel(ids); taskOptions{b}=local;
    warm=ids(ids<=size(seeds,2)); taskSeeds{b}=seeds(:,warm);
end
if useWorkers
    parfor b=1:count
        answers{b}=leo_v16_sb_batch(q,taskOptions{b},taskSeeds{b},randomSeeds(b),kernel);
    end
else
    for b=1:count, answers{b}=leo_v16_sb_batch(q,taskOptions{b},taskSeeds{b},randomSeeds(b),kernel); end
end
if useWorkers
    assert(all(cellfun(@(a)a.workerExecuted,answers)),'SB tasks did not execute on parallel workers.');
end
r=answers{1}; r.bits=zeros(q.nBits,R); r.energy=zeros(1,R);
if isfield(r,'legalGroups'), r.legalGroups=false(q.nUsers,R); end
steps=[]; r.steps=0; r.trajectorySteps=0; r.denseTerms=0; r.restarts=0;
r.uniqueRepairs=0; r.repairCacheHits=0;
for b=1:count
    a=answers{b}; ids=ranges{b}; r.bits(:,ids)=a.bits; r.energy(ids)=a.energy;
    if isfield(a,'legalGroups'), r.legalGroups(:,ids)=a.legalGroups; end
    steps=union(steps,a.history.step); r.steps=max(r.steps,a.steps);
    r.trajectorySteps=r.trajectorySteps+a.trajectorySteps; r.denseTerms=r.denseTerms+a.denseTerms;
    r.restarts=r.restarts+a.restarts;
    if isfield(a,'uniqueRepairs'), r.uniqueRepairs=r.uniqueRepairs+a.uniqueRepairs; r.repairCacheHits=r.repairCacheHits+a.repairCacheHits; end
end
% Pool all per-trajectory energies; median-of-batch-medians would be incorrect.
allEnergy=zeros(R,numel(steps));
for b=1:count
    a=answers{b};
    for t=1:numel(steps)
        at=find(a.history.step<=steps(t),1,'last');
        allEnergy(ranges{b},t)=a.energyByTrajectory(:,at);
    end
end
r.history=struct('step',reshape(steps,1,[]),'minimum',min(allEnergy,[],1), ...
    'median',median(allEnergy,1),'maximum',max(allEnergy,[],1));
r.energyByTrajectory=allEnergy; r.trajectories=R; r.parallelWorkers=workers;
r.parallelTasks=count; r.batchSeeds=randomSeeds; r.stoppedByTime=false;
r.executionBackend=backend;
end
