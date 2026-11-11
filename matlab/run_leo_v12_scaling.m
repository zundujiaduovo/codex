function study = run_leo_v12_scaling(directory,overrides,render)
%RUN_LEO_V12_SCALING 固定算法配置的K/M规模实验；时间截断明确标记，不拟合复杂度阶。
% 每个(K,M)内方法共用模型/初态/种子。random_cap用于所有K，避免32用户特殊布局。
if nargin<1, directory=fullfile('results','v12_scaling'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
method=leo_method_options(struct('fairnessRounds',4,'throughputRounds',2,'originalSearchRounds',6,'verbose',false));
o=struct('userCounts',[8,16,32],'resourceCounts',20,'sceneSeed',71669974, ...
    'seeds',71669974+(0:2)*104729,'budgetSeconds',60,'qosTargetBits',1e6, ...
    'parameters',leo_v12_parameters(),'method',method);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names)
    if strcmp(names{j},'method')
        fields=fieldnames(overrides.method); for k=1:numel(fields), o.method.(fields{k})=overrides.method.(fields{k}); end
    else, o.(names{j})=overrides.(names{j}); end
end
for name={'userCounts','resourceCounts'}
    v=o.(name{1}); assert(isnumeric(v) && isvector(v) && ~isempty(v) && all(isfinite(v) & v>=1 & v==fix(v)) && numel(unique(v))==numel(v));
end
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds) && all(isfinite(o.seeds) & o.seeds>=0 & o.seeds<=2^32-1 & o.seeds==fix(o.seeds)) && numel(unique(o.seeds))==numel(o.seeds));
assert(isscalar(o.sceneSeed) && isfinite(o.sceneSeed) && o.sceneSeed>=0 && o.sceneSeed<=2^32-1 && o.sceneSeed==fix(o.sceneSeed));
assert(isscalar(o.budgetSeconds) && isfinite(o.budgetSeconds) && o.budgetSeconds>0);
assert(isscalar(o.qosTargetBits) && isfinite(o.qosTargetBits) && o.qosTargetBits>0);
o.method=leo_method_options(o.method);
assert(strcmp(o.parameters.problem.objectiveMode,'lexicographic_max_min'));
if ~exist(directory,'dir'), mkdir(directory); end
methods={'original_greedy','original_tabu','sb_v12_lexicographic','local_v12_lexicographic'};
protocol=struct('version','V12 empirical scaling 1','options',o,'methods',{methods});
rows=struct([]);
for K=o.userCounts(:).'
    for M=o.resourceCounts(:).'
        model=[];
        for si=1:numel(o.seeds)
            seed=o.seeds(si); name=sprintf('K%d_M%d_seed%.0f',K,M,seed); out=fullfile(directory,name);
            path=fullfile(out,'scaling_case.mat');
            if exist(path,'file')==2
                saved=load(path,'report','savedProtocol'); assert(isequaln(saved.savedProtocol,protocol),'Scaling protocol changed; use a new output directory.');
                report=saved.report; fprintf('V12 scaling %s retained.\n',name);
            else
                if isempty(model)
                    p=o.parameters; p.seed=o.sceneSeed; p.system.K=K; p.system.qosTargetBits=o.qosTargetBits;
                    p.problem.referenceBits=[]; p.users.layout='random_cap'; p.time.nSlots=M*p.time.blockSlots;
                    p.method.enabled=false; p.exhaustive.enabled=false;
                    model=run_leo_sinr(p,false);
                end
                order=mod((0:3)+si-1,4)+1;
                b=struct('methods',{methods(order)},'seeds',seed,'budgetSeconds',o.budgetSeconds, ...
                    'method',o.method,'exhaustive',false,'makePlots',false,'diagnosticSurrogates',false,'outputDirectory','','verbose',true);
                report=leo_benchmark_case(model,b); report.caseName=name;
                assert(all(strcmp({report.records.status},'completed')),'A scaling method failed; incomplete cases are not cached.');
                if ~exist(out,'dir'), mkdir(out); end
                savedProtocol=protocol; temporary=[tempname(out),'.mat']; save(temporary,'report','savedProtocol','-v7');
                [ok,message]=movefile(temporary,path); assert(ok,message);
            end
            analysis=run_leo_v12_diagnostics(report,out,false);
            for j=1:numel(analysis.workload)
                row=analysis.workload(j); row.K=K; row.M=M; row.scheduleVariables=K*M;
                row.availableVariables=nnz(report.problemData.available); row.maxStreams=report.problemData.maxStreams;
                row.physicalSceneSeed=o.sceneSeed; row.fairnessRoundCap=o.method.fairnessRounds;
                row.throughputRoundCap=o.method.throughputRounds; row.originalRoundCap=o.method.originalSearchRounds;
                row.sbStepCap=o.method.sbSteps; row.sbTrajectories=o.method.sbTrajectories;
                row.localRestarts=o.method.localRestarts; row.status='completed';
                rows=leo_append_struct(rows,row);
            end
            for j=1:numel(report.records)
                if ~strcmp(report.records(j).status,'completed')
                    error('leo:scalingRunFailed','%s / %s: %s',name,report.records(j).method,report.records(j).message);
                end
            end
        end
    end
end
summary=struct([]);
for K=o.userCounts(:).'
    for M=o.resourceCounts(:).'
        for method=methods
            selected=rows([rows.K]==K & [rows.M]==M & strcmp({rows.method},method{1}));
            keep=selected(~[selected.censoredByTime]);
            row=struct('method',method{1},'K',K,'M',M,'runs',numel(selected),'timeCensoredRuns',sum([selected.censoredByTime]), ...
                'medianAllElapsedSeconds',median([selected.endToEndSeconds]),'medianUncensoredElapsedSeconds',NaN, ...
                'medianUncensoredSearchSeconds',NaN,'medianFairness',median([selected.fairness]), ...
                'medianTotalBits',median([selected.totalBits]),'medianOriginalCandidateScores',median([selected.recordedOriginalCandidateScores]), ...
                'medianDenseDynamicsTerms',median([selected.denseDynamicsTerms]),'medianRetainedResultBytes',median([selected.retainedResultBytes]), ...
                'medianUncensoredOriginalCandidateScores',NaN,'medianUncensoredDenseDynamicsTerms',NaN);
            if ~isempty(keep)
                row.medianUncensoredElapsedSeconds=median([keep.endToEndSeconds]); row.medianUncensoredSearchSeconds=median([keep.searchSeconds]);
                row.medianUncensoredOriginalCandidateScores=median([keep.recordedOriginalCandidateScores]);
                row.medianUncensoredDenseDynamicsTerms=median([keep.denseDynamicsTerms]);
            end
            summary=leo_append_struct(summary,row);
        end
    end
end
study=struct('protocol',protocol,'runs',rows,'summary',summary,'runtime',version,'platform',computer, ...
    'scope','Empirical scaling of configured heuristics; per-algorithm iteration caps differ. Censored times do not establish growth rates. Retained result bytes exclude peak/transient/BLAS memory. No certificate or Monte Carlo time is included.');
leo_write_struct_csv(fullfile(directory,'scaling_runs.csv'),rows); leo_write_struct_csv(fullfile(directory,'scaling_summary.csv'),summary);
save(fullfile(directory,'scaling.mat'),'study','-v7');
specs=make_specs(study); fid=fopen(fullfile(directory,'v12_scaling_specs.json'),'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
if render, leo_render_plot_specs(specs,directory); end
fprintf('V12 scaling: %d runs; %d time-censored. Empirical results and fixed configuration exported.\n',numel(rows),sum([rows.censoredByTime]));
end
function specs=make_specs(study)
p=panel('Elapsed time for uncensored configured runs','Users K','Median seconds');
p(2)=panel('Quality returned by the same fixed configurations','Users K','Median uncapped min G/q');
p(3)=panel('Recorded original candidate scores','Users K','Median recorded scores');
p(4)=panel('SB dense force-update work: sum N^2 R steps','Users K','Median scalar multiply terms');
s=study.summary;
for M=study.protocol.options.resourceCounts(:).'
    for method=study.protocol.methods
        r=s([s.M]==M & strcmp({s.method},method{1})); [~,order]=sort([r.K]); r=r(order);
        label=sprintf('%s / M=%d',method{1},M);
        p(1)=add(p(1),label,[r.K],[r.medianUncensoredElapsedSeconds]);
        p(2)=add(p(2),label,[r.K],[r.medianFairness]);
        p(3)=add(p(3),label,[r.K],[r.medianUncensoredOriginalCandidateScores]);
        if strcmp(method{1},'sb_v12_lexicographic'), p(4)=add(p(4),label,[r.K],[r.medianUncensoredDenseDynamicsTerms]); end
    end
end
for j=1:4, p(j).note=study.scope; end
specs=struct('name','v12_empirical_scaling','title','V12 empirical scaling | fixed algorithm settings | censored runtime excluded','rows',2,'cols',2,'panels',p);
end
function p=panel(titleText,xlabelText,ylabelText)
p=struct('kind','line','title',titleText,'xlabel',xlabelText,'ylabel',ylabelText,'labels',{{}}, ...
    'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=add(p,name,x,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]));
end
