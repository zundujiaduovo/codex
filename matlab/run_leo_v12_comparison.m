function [report,files] = run_leo_v12_comparison(directory,overrides,render)
%RUN_LEO_V12_COMPARISON V12：先未封顶max-min，再严格保持阶段1公平提高总保证服务。
% 独立输出目录/协议；已有V12配对可恢复，V10/V11数据不可混用。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
o=leo_v12_options(overrides); protocol=rmfield(o,'prepareOnly');
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
if ~exist(directory,'dir'), mkdir(directory); end
path=fullfile(directory,'experiment.mat');
if exist(path,'file')==2
    saved=load(path,'experiment'); experiment=saved.experiment;
    assert(strcmp(experiment.version,'V12 uncapped lexicographic') && isequaln(experiment.protocol,protocol), ...
        'This output directory has a different objective/protocol. Use a new V12 directory.');
else
    p=o.parameters; p.method.enabled=false; p.exhaustive.enabled=false;
    model=run_leo_sinr(p,false);
    experiment=struct('version','V12 uncapped lexicographic','baseCommit','37bbe3d72cbb13b26fa1e6a5384391afddd64020', ...
        'objectiveMode','lexicographic_max_min','protocol',protocol, ...
        'methods',{{'original_tabu','sb_v12_lexicographic','local_v12_lexicographic'}}, ...
        'modelSnapshot',rmfield(model,'problem'),'problemData',model.problem.data, ...
        'runtime',version,'platform',computer);
    save(path,'experiment','-v7');
end
fprintf('V12 CHANGED OBJECTIVE: maximize UNCAPPED s=min_i G_i/q_i; then maximize sum(G_i) with every ratio >= attained stage-1 s.\n');
fprintf('%d search seed(s), 3 methods, %.0f s/method; fairness phase fraction %.2f.\n',numel(o.seeds),o.budgetSeconds,o.method.fairnessBudgetFraction);
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
