function [o,folder]=V16_SETTINGS()
% V16: 64 SB trajectories, real process-pool parallelism, no outer iteration cap.
o=struct('sceneSeed',71669974,'seeds',71669974,'budgetSeconds',Inf, ...
    'validationSamples',1000,'validationSeed',71774703,'prepareOnly',false, ...
    'parameters',leo_v13_parameters());
m=struct('iterationOnly',true,'sbSteps',500,'sbTrajectories',64,'localRestarts',64, ...
    'fairnessRounds',240,'throughputRounds',120,'originalFairnessRounds',2000, ...
    'originalThroughputRounds',1000,'polishMoves',12,'refreshEvery',1,'fastPolish',true, ...
    'fairnessStep',1,'throughputStep',.15,'referenceMode','current_schedule', ...
    'proxyTabuIterations',80,'proxyTabuRestarts',4,'proxyTabuTenure',7);
m.coordination=leo_v14_coordination_options();
m.refinement=struct('candidatePool',true,'bottleneckCandidates',true,'candidateRefresh',true,'poolSize',12);
m.audit=struct('enabled',true,'snapshots',4,'tabuMoves',16); m.stopping=struct('enabled',false);
m.parallel=leo_v16_parallel_options(struct('enabled',true,'workers',0,'batchSize',8));
m.convergence=leo_v16_convergence_options(struct('enabled',true));
o.method=m;
o.fairnessCertificateOptions=struct('maxSeconds',Inf,'relativeGap',.001,'absoluteGap',1e-6);
o.throughputCertificateOptions=struct('maxSeconds',Inf,'relativeGap',.001);
o=leo_v12_options(o);
folder='v16_parallel64_until_convergence';
end
