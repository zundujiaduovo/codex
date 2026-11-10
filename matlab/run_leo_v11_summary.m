function summary = run_leo_v11_summary(directory,render)
%RUN_LEO_V11_SUMMARY 复核全部配对、独立计算一次原模型共同界、导出配对统计。
% 上界/证书日程仅用于事后评价，不输入任何被测方法。
if nargin<2, render=true; end
saved=load(fullfile(directory,'experiment.mat'),'experiment'); e=saved.experiment; o=e.protocol;
report=struct();
for seed=o.seeds
    path=fullfile(directory,'pairs',sprintf('seed_%.0f.mat',seed));
    assert(exist(path,'file')==2,['Missing pair: ',path]);
    saved=load(path,'report'); pair=saved.report;
    assert(isequaln(pair.pairedProtocol,o) && isequaln(pair.problemData,e.problemData),'Mismatched paired model/protocol.');
    assert(numel(pair.records)==3 && all([pair.records.seed]==seed));
    assert(numel(unique({pair.records.method}))==3 && all(ismember(e.methods,{pair.records.method})));
    for j=1:3
        if ~strcmp(pair.records(j).status,'completed'), continue; end
        s=leo_evaluate_service(e.problemData,pair.solutions{j}.x);
        assert(abs(s.totalBits-pair.records(j).totalBits)<1e-8*max(1,s.totalBits));
        assert(all(s.userBits>=e.problemData.qosTargetBits)==pair.records(j).fullQosFeasible);
    end
    if isempty(fieldnames(report)), report=pair;
    else
        report.records=[report.records;pair.records(:)];
        report.solutions=[report.solutions;pair.solutions(:)];
    end
end
report.options.methods=e.methods; report.options.seeds=o.seeds; report.options.outputDirectory=directory;
report.summary=leo_summarize_benchmark(report.records,e.methods);
theoryPath=fullfile(directory,'theoretical_bound.mat');
if exist(theoryPath,'file')
    saved=load(theoryPath,'theory');
    assert(isequaln(saved.theory.problemDataSnapshot,e.problemData),'Saved bound belongs to a different model.');
    report.theory=saved.theory;
end
if ~isfield(report,'theory'), report.theory=leo_theory_bound(report,o.theoryOptions); end
% 历史界可复用；逐运行可行性/成绩始终重建，不能沿用别的记录顺序。
t=report.theory; t.recordServiceBits=NaN(numel(report.records),1); t.recordFeasible=false(numel(report.records),1);
for j=1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed'), continue; end
    s=leo_evaluate_service(e.problemData,report.solutions{j}.x);
    t.recordServiceBits(j)=s.totalBits; t.recordFeasible(j)=all(s.userBits>=e.problemData.qosTargetBits);
    if t.recordFeasible(j)
        assert(s.totalBits<=t.upperBits+1e-8*max(1,t.upperBits),'Common bound is below a feasible original-model result.');
        if ~isfinite(t.lowerBits) || s.totalBits>t.lowerBits
            t.lowerBits=s.totalBits; t.incumbentX=report.solutions{j}.x;
            t.bestMethod=report.records(j).method; t.bestSeed=report.records(j).seed;
        end
    end
end
t.absoluteGapBits=t.upperBits-t.lowerBits; t.relativeGap=t.absoluteGapBits/t.upperBits;
t.gapTargetMet=isfinite(t.lowerBits) && t.absoluteGapBits<=max(t.targetAbsoluteGapBits,t.targetRelativeGap*t.upperBits);
report.theory=t; leo_export_theory_bound(report,directory);
data=leo_v11_trace_data(report);
metricOptions=struct('deadlinesSeconds',unique([1,5,10,30,60,o.budgetSeconds]));
metrics=leo_performance_metrics(data,metricOptions);
leo_write_struct_csv(fullfile(directory,'search_checkpoints.csv'),data.progress);
leo_write_struct_csv(fullfile(directory,'runs.csv'),report.records);
leo_write_struct_csv(fullfile(directory,'performance_summary.csv'),metrics.summary);
leo_write_struct_csv(fullfile(directory,'time_to_quality.csv'),metrics.targets);
leo_write_struct_csv(fullfile(directory,'quality_at_deadlines.csv'),metrics.deadlines);
export_original_schedules(report,directory);
pairs=make_pairs(report,metrics,o);
statistics=leo_v11_paired_statistics(pairs,o);
methodSummary=method_summary(report,metrics,e.methods,o);
targetSummary=target_summary(metrics,e.methods,o);
summary=struct('version',e.version,'baseCommit',e.baseCommit,'protocol',o, ...
    'runtime',e.runtime,'platform',e.platform,'scope',e.scope, ...
    'pairs',pairs,'statistics',statistics,'methods',methodSummary,'targets',targetSummary, ...
    'theoryUpperBits',t.upperBits,'theoryLowerBits',t.lowerBits,'theoryRelativeGap',t.relativeGap);
leo_write_struct_csv(fullfile(directory,'paired_differences.csv'),pairs);
leo_write_struct_csv(fullfile(directory,'paired_statistics.csv'),statistics);
leo_write_struct_csv(fullfile(directory,'method_summary.csv'),methodSummary);
leo_write_struct_csv(fullfile(directory,'target_success_summary.csv'),targetSummary);
save(fullfile(directory,'paired_summary.mat'),'summary','metrics','-v7');
specs=leo_build_v11_paired_specs(summary);
fid=fopen(fullfile(directory,'v11_paired_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
write_readme(directory,summary);
if render, leo_render_plot_specs(specs,directory); end
for j=1:numel(statistics)
    s=statistics(j);
    fprintf('SB vs %s: %d/%d available; W/T/L=%d/%d/%d; mean delta %.6f Mbit, 95%% CI [%.6f, %.6f].\n', ...
        s.baseline,s.availablePairs,s.expectedPairs,s.wins,s.ties,s.losses, ...
        s.meanDeltaBits/1e6,s.meanDelta95LowBits/1e6,s.meanDelta95HighBits/1e6);
end
end
function pairs=make_pairs(report,metrics,o)
pairs=struct([]); baselines={'original_tabu','local_v8_blockwise'};
for seed=o.seeds
    a=report.records(strcmp({report.records.method},'sb_v8_blockwise') & [report.records.seed]==seed);
    for j=1:2
        b=report.records(strcmp({report.records.method},baselines{j}) & [report.records.seed]==seed);
        r=struct('seed',seed,'method','sb_v8_blockwise','baseline',baselines{j}, ...
            'methodStatus',a.status,'baselineStatus',b.status,'methodFullQos',a.fullQosFeasible, ...
            'baselineFullQos',b.fullQosFeasible,'methodCertifiedBits',NaN,'baselineCertifiedBits',NaN, ...
            'deltaBits',NaN,'relativeGainPercent',NaN,'deltaBudgetBits',NaN, ...
            'methodEndToEndSeconds',a.endToEndSeconds,'baselineEndToEndSeconds',b.endToEndSeconds);
        if strcmp(a.status,'completed') && a.fullQosFeasible, r.methodCertifiedBits=a.totalBits; end
        if strcmp(b.status,'completed') && b.fullQosFeasible, r.baselineCertifiedBits=b.totalBits; end
        if isfinite(r.methodCertifiedBits) && isfinite(r.baselineCertifiedBits)
            r.deltaBits=a.totalBits-b.totalBits;
            r.relativeGainPercent=100*r.deltaBits/b.totalBits;
        end
        rows=metrics.deadlines([metrics.deadlines.seed]==seed & [metrics.deadlines.deadlineSeconds]==o.budgetSeconds);
        av=rows(strcmp({rows.method},a.method)); bv=rows(strcmp({rows.method},b.method));
        r.deltaBudgetBits=av.certifiedBits-bv.certifiedBits;
        pairs=leo_append_struct(pairs,r);
    end
end
end
function rows=method_summary(report,metrics,methods,o)
rows=struct([]);
for j=1:numel(methods)
    runs=report.records(strcmp({report.records.method},methods{j}));
    keep=strcmp({runs.status},'completed') & [runs.fullQosFeasible]; values=[runs(keep).totalBits];
    r=struct('method',methods{j},'expectedRuns',numel(o.seeds),'completedRuns',sum(strcmp({runs.status},'completed')), ...
        'fullQosRuns',sum(keep),'meanCertifiedBits',NaN,'medianCertifiedBits',NaN, ...
        'minCertifiedBits',NaN,'maxCertifiedBits',NaN,'meanUpperGapPercent',NaN, ...
        'meanTimeAverageGapPercent',NaN,'meanActualSampleBits',NaN, ...
        'meanJointSuccessRate',NaN,'maxJointFailure95Upper',NaN);
    if ~isempty(values)
        r.meanCertifiedBits=mean(values); r.medianCertifiedBits=median(values);
        r.minCertifiedBits=min(values); r.maxCertifiedBits=max(values);
        r.meanUpperGapPercent=100*(1-mean(values)/report.theory.upperBits);
    end
    selected=metrics.summary(strcmp({metrics.summary.method},methods{j}));
    r.meanTimeAverageGapPercent=finite_mean([selected.timeAverageGapPercent]);
    r.meanActualSampleBits=finite_mean([runs.sampleMeanTotalBits]);
    r.meanJointSuccessRate=finite_mean([runs.sampleJointSuccessRate]);
    a=[runs.sampleJointFailure95Upper]; a=a(isfinite(a));
    if ~isempty(a), r.maxJointFailure95Upper=max(a); end
    rows=leo_append_struct(rows,r);
end
end
function rows=target_summary(metrics,methods,o)
rows=struct([]);
for j=1:numel(methods)
    for target=metrics.options.gapTargetsPercent
        selected=metrics.targets(strcmp({metrics.targets.method},methods{j}) & [metrics.targets.targetGapPercent]==target);
        hit=[selected.hitWithinBudget]; times=[selected(hit).firstRecordedHitSeconds];
        r=struct('method',methods{j},'targetGapPercent',target,'expectedRuns',numel(o.seeds), ...
            'reachedWithinBudget',sum(hit),'successRate',sum(hit)/numel(o.seeds),'medianHitSecondsAmongReached',NaN);
        if ~isempty(times), r.medianHitSecondsAmongReached=median(times); end
        rows=leo_append_struct(rows,r);
    end
end
end
function v=finite_mean(v)
v=v(isfinite(v)); if isempty(v), v=NaN; else, v=mean(v); end
end
function write_readme(directory,s)
fid=fopen(fullfile(directory,'RESULTS.md'),'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# V11 based on V10: paired search results\n\n');
fprintf(fid,'Runtime: %s; platform: %s. Scene seed: %.0f; %d search seeds; %.0f s/method.\n\n', ...
    s.runtime,s.platform,s.protocol.sceneSeed,numel(s.protocol.seeds),s.protocol.budgetSeconds);
fprintf(fid,'All scores are evaluated by the original certified-service model. The quadratic proxy generates search candidates only.\n\n');
fprintf(fid,'This repeats search randomness on ONE fixed physical model. It does not measure robustness across different user layouts.\n\n');
fprintf(fid,'Original-model optimum interval: [%.9f, %.9f] Mbit/period; remaining certificate gap %.6f%%.\n\n', ...
    s.theoryLowerBits/1e6,s.theoryUpperBits/1e6,100*s.theoryRelativeGap);
fprintf(fid,'| Comparison | Valid/expected | SB wins/ties/losses | Mean delta (Mbit) | Pointwise 95%% paired bootstrap CI | Holm sign p |\n|---|---:|---:|---:|---:|---:|\n');
for j=1:numel(s.statistics)
    r=s.statistics(j);
    fprintf(fid,'| SB vs %s | %d/%d | %d/%d/%d | %.6f | [%.6f, %.6f] | %.6g |\n', ...
        r.baseline,r.availablePairs,r.expectedPairs,r.wins,r.ties,r.losses,r.meanDeltaBits/1e6, ...
        r.meanDelta95LowBits/1e6,r.meanDelta95HighBits/1e6,r.signTestHolmP);
end
fprintf(fid,'\nFinal returned scores follow the V10 soft-budget convention; exact-deadline differences are also in paired_statistics.csv.\n');
fprintf(fid,'Missing/failed/non-QoS runs remain missing. Reached-only median times must be read together with target success counts.\n');
fprintf(fid,'95%% mean CIs are pointwise percentile bootstrap intervals, not simultaneous guarantees. The two primary sign tests use Holm correction.\n');
fprintf(fid,'Independent fading means and validation success frequencies are separate from the certified objective and its upper bound.\n');
end
function export_original_schedules(report,directory)
% 直接导出原问题日程与逐用户服务，避免为多种子展开大体积价格日志。
schedule=fopen(fullfile(directory,'schedules.csv'),'w','n','UTF-8'); assert(schedule>=0);
closeSchedule=onCleanup(@() fclose(schedule)); %#ok<NASGU>
users=fopen(fullfile(directory,'user_service.csv'),'w','n','UTF-8'); assert(users>=0);
closeUsers=onCleanup(@() fclose(users)); %#ok<NASGU>
fprintf(schedule,'method,seed,user,resource,selected,beam\n');
fprintf(users,'method,seed,user,targetBits,serviceBits,demandRatio\n');
counts=struct([]);
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    solution=report.solutions{j}; s=leo_evaluate_service(report.problemData,solution.x);
    for i=1:report.problemData.shape(1)
        fprintf(users,'"%s",%.0f,%d,%.17g,%.17g,%.17g\n',r.method,r.seed,i, ...
            report.problemData.qosTargetBits(i),s.userBits(i),s.demandRatio(i));
        for m=1:report.problemData.shape(2)
            fprintf(schedule,'"%s",%.0f,%d,%d,%d,%d\n',r.method,r.seed,i,m, ...
                solution.x(i,m),report.problemData.beamIndex(i,m));
        end
    end
    row=struct('method',r.method,'seed',r.seed,'nativeStage1Iterations',NaN,'nativeStage2Iterations',NaN, ...
        'sbIntegrationSteps',NaN,'proxyRefreshes',NaN,'initialCertifiedBits',r.initialTotalBits);
    for phase=1:2
        stage=solution.(sprintf('stage%d',phase)); field=sprintf('nativeStage%dIterations',phase);
        if isfield(stage,'rounds'), row.(field)=stage.rounds;
        elseif isfield(stage,'iterations'), row.(field)=stage.iterations; end
    end
    if isfield(solution.stage2,'rounds')
        row.sbIntegrationSteps=sum(solution.stage1.history.sbSteps)+sum(solution.stage2.history.sbSteps);
        row.proxyRefreshes=max(0,numel(solution.stage1.proxyEpochFairnessErrorBounds)-1)+ ...
            max(0,numel(solution.stage2.proxyEpochFairnessErrorBounds)-1);
    end
    counts=leo_append_struct(counts,row);
end
leo_write_struct_csv(fullfile(directory,'run_counts.csv'),counts);
end
