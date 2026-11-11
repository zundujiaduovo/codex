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
fprintf('K=%d, NB=%d, L=%d; admission %.0f%%; nRF=%d, p0=%.3g W, Pmax=%.3g W.\n', ...
    o.parameters.system.K,o.parameters.array.nBeams,o.parameters.system.maxStreams, ...
    100*o.parameters.system.maxStreams/o.parameters.array.nBeams,o.parameters.system.nRF, ...
    o.parameters.system.streamPowerW,o.parameters.system.maxPowerW);
fprintf('%d search seed(s), %d methods, at most %.0f s/method; fairness phase fraction %.2f.\n',numel(o.seeds),numel(experiment.methods),o.budgetSeconds,o.method.fairnessBudgetFraction);
if isfield(o.method,'stopping') && o.method.stopping.enabled
    s=o.method.stopping;
    fprintf('Auto stop: valid original-model gap <= %.3g%%; or %.3g s without %.3g%% cumulative improvement (min %.3g s and %d native iterations/phase).\n', ...
        100*s.relativeGap,s.patienceSeconds,100*s.relativeImprovement,s.minPhaseSeconds,s.minIterations);
end
fprintf('Output: %s\n',directory);
originalModel=struct('problemData',experiment.problemData,'parameters',experiment.modelSnapshot.parameters,'protocol',protocol,'version',experiment.version);
save(fullfile(directory,'original_model.mat'),'originalModel','-v7');
metadata=rmfield(experiment,{'modelSnapshot','problemData'}); fid=fopen(fullfile(directory,'experiment_protocol.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(metadata)); fclose(fid);
files={}; report=experiment;
if o.prepareOnly, return; end
for seed=o.seeds, run_leo_v12_pair(directory,seed); end
[report,files]=run_leo_v12_summary(directory,render);
end
