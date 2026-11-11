function [report,files] = run_leo_v12_comparison(directory,overrides,render,releaseTag)
%RUN_LEO_V12_COMPARISON V12：先未封顶max-min，再严格保持阶段1公平提高总保证服务。
% 独立输出目录/协议；已有V12配对可恢复，V10/V11数据不可混用。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
if nargin<4, releaseTag='V12'; end
release=leo_lexicographic_release(releaseTag);
o=leo_v12_options(overrides); protocol=rmfield(o,'prepareOnly');
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
if ~exist(directory,'dir'), mkdir(directory); end
path=fullfile(directory,'experiment.mat');
if exist(path,'file')==2
    saved=load(path,'experiment'); experiment=saved.experiment;
    assert(strcmp(experiment.version,release.version) && isequaln(experiment.protocol,protocol), ...
        'This output directory has a different version/objective/protocol. Use a new directory.');
else
    p=o.parameters; p.method.enabled=false; p.exhaustive.enabled=false;
    model=run_leo_sinr(p,false);
    experiment=struct('version',release.version,'baseCommit',release.baseCommit, ...
        'objectiveMode','lexicographic_max_min','protocol',protocol, ...
        'methods',{release.methods}, ...
        'modelSnapshot',rmfield(model,'problem'),'problemData',model.problem.data, ...
        'runtime',version,'platform',computer);
    save(path,'experiment','-v7');
end
fprintf('%s: maximize UNCAPPED s=min_i G_i/q_i; then maximize sum(G_i) with every ratio >= attained stage-1 s.\n',release.version);
fprintf('K=%d, Na=%d (%dx%d), NB=%d, L=%d; admission %.0f%%; nRF=%d, p0=%.3g W, Pmax=%.3g W.\n', ...
    o.parameters.system.K,o.parameters.array.nElements,o.parameters.array.nX,o.parameters.array.nY, ...
    o.parameters.array.nBeams,o.parameters.system.maxStreams, ...
    100*o.parameters.system.maxStreams/o.parameters.array.nBeams,o.parameters.system.nRF, ...
    o.parameters.system.streamPowerW,o.parameters.system.maxPowerW);
if leo_iteration_only(o.method)
    fprintf('%d search seed(s), %d methods; FIXED MAXIMUM ITERATIONS, no wall-clock/gap/stagnation stopping.\n',numel(o.seeds),numel(experiment.methods));
    fprintf('Tabu: %d fairness + %d throughput rounds. SB/Local/Proxy+Tabu: %d fairness + %d throughput price rounds.\n', ...
        o.method.originalFairnessRounds,o.method.originalThroughputRounds,o.method.fairnessRounds,o.method.throughputRounds);
    fprintf('Greedy: at most the corresponding original-search round cap; ends naturally when no improving addition exists.\n');
else
    fprintf('%d search seed(s), %d methods, at most %.0f s/method; fairness phase fraction %.2f.\n',numel(o.seeds),numel(experiment.methods),o.budgetSeconds,o.method.fairnessBudgetFraction);
end
if isfield(o.method,'stopping') && o.method.stopping.enabled
    s=o.method.stopping;
    fprintf('Auto stop: valid original-model gap <= %.3g%%; or %.3g s without %.3g%% cumulative improvement (min %.3g s and %d native iterations/phase).\n', ...
        100*s.relativeGap,s.patienceSeconds,100*s.relativeImprovement,s.minPhaseSeconds,s.minIterations);
end
if any(strcmp(release.tag,{'V13','V14'}))
    if isfield(o.method,'refinement')
        r=o.method.refinement;
        fprintf('Proxy refinement: pool=%d (max %d per call), bottleneck candidates=%d (band %.4g), candidate tangent refresh=%d (gap trigger %.4g demand ratio).\n', ...
            r.candidatePool,r.poolSize,r.bottleneckCandidates,r.bottleneckBand,r.candidateRefresh,r.gapTrigger);
    end
    fprintf('Search profile: SB %d steps x %d trajectories; Local %d restarts; polish %d moves; refresh every %d rounds.\n', ...
        o.method.sbSteps,o.method.sbTrajectories,o.method.localRestarts,o.method.polishMoves,o.method.refreshEvery);
    if isfield(o.method,'proxyTabuIterations')
        fprintf('Proxy+Tabu inner: %d iterations x %d starts, tabu tenure %d; same surrogate/price/original-acceptance framework as SB/Local.\n', ...
            o.method.proxyTabuIterations,o.method.proxyTabuRestarts,o.method.proxyTabuTenure);
    end
    leo_print_bound_explanation(struct('problemData',experiment.problemData,'parameters',o.parameters));
end
if strcmp(release.tag,'V14')
    fprintf('V14 fairness: simplex weights with smoothed ORIGINAL deficits; no bang-bang auxiliary fairness variable.\n');
    fprintf('V14: shared 2-3 block coordination, gain-error trust region, contextual candidate pool; SB kernel=%s.\n',o.method.coordination.sbKernel);
end
fprintf('Output: %s\n',directory);
originalModel=struct('problemData',experiment.problemData,'parameters',experiment.modelSnapshot.parameters,'protocol',protocol,'version',experiment.version);
save(fullfile(directory,'original_model.mat'),'originalModel','-v7');
metadata=rmfield(experiment,{'modelSnapshot','problemData'});
if leo_iteration_only(o.method)
    metadata.terminationMode='iteration_limits'; metadata.protocol.budgetSeconds=[];
    metadata.budgetNote='No time limit; MATLAB protocol stores Inf. Fixed iteration counts are in protocol.method.';
end
fid=fopen(fullfile(directory,'experiment_protocol.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(metadata)); fclose(fid);
files={}; report=experiment;
if o.prepareOnly, return; end
for seed=o.seeds, run_leo_v12_pair(directory,seed); end
[report,files]=run_leo_v12_summary(directory,render);
end
