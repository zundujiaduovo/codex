function experiment = run_leo_v11_paired(directory,overrides,render)
%RUN_LEO_V11_PAIRED V11基于V10：同一模型、20搜索种子、Tabu/SB/配对Local。
% 默认约20*3*120秒搜索，另有一次共同上界和独立验证。已有完整配对可恢复。
% prepareOnly=true只创建协议；可逐个调用run_leo_v11_pair后再汇总。
if nargin<1, directory=fullfile('results','v11_based_on_v10_paired'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
o=leo_v11_paired_options(overrides);
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
if ~exist(directory,'dir'), mkdir(directory); end
path=fullfile(directory,'experiment.mat');
protocol=rmfield(o,'prepareOnly');
if exist(path,'file')
    saved=load(path,'experiment'); experiment=saved.experiment;
    assert(isequaln(experiment.protocol,protocol),'Existing experiment has a different protocol; use a new output directory.');
else
    % 一个冻结场景配对重复搜索；搜索种子不改变用户、概率证书或校准日程。
    p=leo_paper_parameters(); p.seed=o.sceneSeed; p.method.enabled=false; p.exhaustive.enabled=false;
    model=run_leo_sinr(p,false); modelSnapshot=rmfield(model,'problem');
    experiment=struct('version','V11 based on V10','baseCommit','26759eac9899da48b0e30da38c880e6d44a757da', ...
        'protocol',protocol,'methods',{{'original_tabu','sb_v8_blockwise','local_v8_blockwise'}}, ...
        'modelSnapshot',modelSnapshot,'problemData',model.problem.data, ...
        'runtime',version,'platform',computer, ...
        'scope','Repeated SEARCH seeds on one fixed V10 model; not independent user layouts.');
    save(path,'experiment','-v7');
    leo_write_struct_csv(fullfile(directory,'search_seeds.csv'),seed_rows(o.seeds));
end
fprintf('V11 based on V10: %d paired search seeds, 3 methods, %.0f s/method; scene seed %.0f.\n', ...
    numel(o.seeds),o.budgetSeconds,o.sceneSeed);
fprintf('Output: %s\n',directory);
metadata=rmfield(experiment,{'modelSnapshot','problemData'});
metadata.shape=experiment.problemData.shape; metadata.maxStreams=experiment.problemData.maxStreams;
fid=fopen(fullfile(directory,'experiment_protocol.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(metadata)); fclose(fid);
originalModel=struct('problemData',experiment.problemData,'parameters',experiment.modelSnapshot.parameters, ...
    'protocol',experiment.protocol,'version',experiment.version,'baseCommit',experiment.baseCommit);
save(fullfile(directory,'original_model.mat'),'originalModel','-v7');
if o.prepareOnly, return; end
for seed=o.seeds, run_leo_v11_pair(directory,seed); end
run_leo_v11_summary(directory,render);
end
function rows=seed_rows(seeds)
rows=struct([]);
for j=1:numel(seeds), rows=leo_append_struct(rows,struct('pairIndex',j,'searchSeed',seeds(j))); end
end
