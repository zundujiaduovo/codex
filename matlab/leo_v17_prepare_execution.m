function runtime=leo_v17_prepare_execution(o)
% Select one GPU for a matrix of trajectories, or a configured CPU worker pool.
e=leo_v17_execution_options(); if isfield(o,'execution'), e=leo_v17_execution_options(o.execution); end
if strcmp(e.backend,'cpu')
    runtime=leo_v16_prepare_parallel(o.parallel); runtime.computeBackend='cpu'; return;
end
timer=tic;
if exist('gcp','file')>0
    pool=gcp('nocreate');
    if ~isempty(pool)
        fprintf('V17 GPU mode: closing %d CPU workers to release system memory.\n',pool.NumWorkers); delete(pool);
    end
end
if exist('gpuDevice','file')==0 || ~license('test','Distrib_Computing_Toolbox')
    error('leo:gpuUnavailable','GPU mode requires Parallel Computing Toolbox and a supported NVIDIA GPU.');
end
try
    device=gpuDevice(e.deviceIndex);
    assert(device.DeviceAvailable,'Selected GPU is not available.');
    % Warm up the CUDA context outside the solver timings and verify array support.
    sample=gpuArray(cast(eye(4),e.precision)); check=gather(sample*sample);
    assert(all(isfinite(check(:)))); clear sample check
    wait(device);
catch err
    error('leo:gpuUnavailable','GPU setup failed: %s',err.message);
end
runtime=struct('enabled',true,'backend','gpuArray','computeBackend','gpu','workers',0, ...
    'deviceIndex',device.Index,'deviceName',device.Name,'computeCapability',device.ComputeCapability, ...
    'totalMemory',device.TotalMemory,'availableMemory',device.AvailableMemory, ...
    'precision',e.precision,'trajectories',o.sbTrajectories,'startupSeconds',toc(timer));
fprintf('V17 GPU ACTIVE: %s, device %d; %.2f GiB available; %d trajectories in one GPU matrix; %s dynamics.\n', ...
    runtime.deviceName,runtime.deviceIndex,runtime.availableMemory/2^30,o.sbTrajectories,e.precision);
fprintf('Original-model evaluation, feasibility repair, Tabu/Local and global bounds remain CPU computations.\n');
end
