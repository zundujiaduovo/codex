function runtime=leo_v16_prepare_parallel(options)
p=leo_v16_parallel_options(options); timer=tic;
runtime=struct('enabled',p.enabled,'backend','serial','workers',0,'startupSeconds',0);
if ~p.enabled, return; end
if exist('parpool','file')==0 || ~license('test','Distrib_Computing_Toolbox')
    error('leo:parallelUnavailable', ['V17 parallel SB requires MATLAB Parallel Computing Toolbox. ', ...
        'Install/activate it to run the requested parallel search. ', ...
        'Explicit serial operation is available only by setting method.parallel.enabled=false in V17_SETTINGS.']);
end
cluster=parcluster('Processes'); workers=p.workers;
if workers==0, workers=min(4,cluster.NumWorkers); end
assert(workers>=2,'V17 needs at least two process workers for parallel search.');
pool=gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers~=workers
    fprintf('V17 resizing existing pool: %d -> %d workers as configured.\n',pool.NumWorkers,workers);
    delete(pool); pool=[];
end
if isempty(pool), pool=parpool(cluster,workers); end
assert(pool.NumWorkers>=2,'Existing pool has only one worker; create a pool with at least two workers.');
% Keep reused local workers on this V17 source path rather than an old checkout.
setup=parfevalOnAll(pool,@addpath,0,fileparts(mfilename('fullpath')),'-begin');
wait(setup);
for j=1:numel(setup), fetchOutputs(setup(j)); end
runtime.backend=class(pool); runtime.workers=pool.NumWorkers; runtime.startupSeconds=toc(timer);
fprintf('V17 SB PARALLEL ACTIVE: %d workers, independent batches of %d trajectories.\n',runtime.workers,p.batchSize);
end
