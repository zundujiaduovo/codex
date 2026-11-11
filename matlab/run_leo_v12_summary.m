function [report,files] = run_leo_v12_summary(directory,render)
%RUN_LEO_V12_SUMMARY 主指标是未封顶公平；吞吐界只能在明确的同一s0下解释。
if nargin<2, render=true; end
saved=load(fullfile(directory,'experiment.mat'),'experiment'); e=saved.experiment; o=e.protocol;
release=leo_lexicographic_release(e.version);
assert(leo_is_lexicographic(e.problemData));
report=struct();
for seed=o.seeds
    path=fullfile(directory,'pairs',sprintf('seed_%.0f.mat',seed)); assert(exist(path,'file')==2,['Missing V12 pair: ',path]);
    loaded=load(path,'report'); pair=loaded.report;
    assert(isequaln(pair.problemData,e.problemData) && isequaln(pair.pairedProtocol,o));
    assert(numel(pair.records)==numel(e.methods) && all([pair.records.seed]==seed));
    assert(numel(unique({pair.records.method}))==numel(e.methods) && all(ismember(e.methods,{pair.records.method})));
    for j=1:numel(pair.records)
        if ~strcmp(pair.records(j).status,'completed'), continue; end
        solution=pair.solutions{j}; service=leo_evaluate_service(e.problemData,solution.x);
        primary=leo_evaluate_service(e.problemData,solution.stage1.x);
        assert(primary.fairness==solution.stage1.service.fairness);
        assert(all(service.demandRatio>=primary.fairness),'Stage 2 lost stage-1 fairness.');
        assert(solution.fairnessFloor==primary.fairness && service.totalBits>=primary.totalBits);
        assert(abs(service.totalBits-pair.records(j).totalBits)<1e-9*max(1,service.totalBits));
    end
    if isempty(fieldnames(report)), report=pair;
    else, report.records=[report.records;pair.records(:)]; report.solutions=[report.solutions;pair.solutions(:)]; end
end
report.options.methods=e.methods; report.options.seeds=o.seeds; report.options.outputDirectory=directory;
report.objectiveMode='lexicographic_max_min'; report.releaseTag=release.tag;
fairPath=fullfile(directory,'fairness_certificate.mat');
if exist(fairPath,'file')==2
    loaded=load(fairPath,'certificate'); certificate=loaded.certificate;
    assert(isequaln(certificate.problemDataSnapshot,e.problemData),'Fairness certificate belongs to another model.');
else
    certificate=leo_fairness_certificate(report,o.fairnessCertificateOptions);
    save(fairPath,'certificate','-v7');
end
report.fairnessCertificate=certificate;
boundsPath=fullfile(directory,'conditional_throughput_bounds.mat');
cache=struct('floors',[],'bounds',{{}},'problemDataSnapshot',e.problemData);
if exist(boundsPath,'file')==2
    loaded=load(boundsPath,'cache'); cache=loaded.cache;
    assert(isequaln(cache.problemDataSnapshot,e.problemData));
end
conditional=struct([]);
for j=1:numel(report.records)
    r=report.records(j); report.records(j).globalFairnessUpper=certificate.upper;
    report.records(j).fairnessGapAtLeast=NaN; report.records(j).fairnessGapAtMost=NaN;
    report.records(j).stage1CertificateConfirmed=false; report.records(j).conditionalThroughputUpperBits=NaN;
    if ~strcmp(r.status,'completed'), continue; end
    floorValue=r.stage1Fairness; at=find(cache.floors==floorValue,1);
    if isempty(at)
        options=o.throughputCertificateOptions; options.fairnessFloor=floorValue;
        t=leo_theory_bound(report,options); cache.floors(end+1)=floorValue; cache.bounds{end+1}=t;
        save(boundsPath,'cache','-v7');
    else, t=cache.bounds{at}; end
    assert(t.upperBits>=r.totalBits-1e-8*max(1,r.totalBits));
    report.records(j).conditionalThroughputUpperBits=t.upperBits;
    report.records(j).fairnessGapAtLeast=max(0,certificate.lower-r.fairness);
    report.records(j).fairnessGapAtMost=max(0,certificate.upper-r.fairness);
    tolerance=max(certificate.options.absoluteGap,certificate.options.relativeGap*max(certificate.upper,eps));
    report.records(j).stage1CertificateConfirmed=certificate.upper-r.stage1Fairness<=tolerance;
    row=struct('method',r.method,'seed',r.seed,'fairnessFloor',floorValue,'methodTotalBits',r.totalBits, ...
        'conditionalLowerBits',t.lowerBits,'conditionalUpperBits',t.upperBits,'relativeIntervalGap',t.relativeGap, ...
        'pricingComplete',t.pricingComplete,'status',t.pricingStatus, ...
        'scope','Conditional sum(G) at this EXACT attained stage-1 floor; totals at different floors are not the same secondary problem.');
    conditional=leo_append_struct(conditional,row);
end
report.conditionalBounds=conditional; report.summary=leo_summarize_benchmark(report.records,e.methods);
report.options.outputDirectory=directory;
leo_write_struct_csv(fullfile(directory,'runs.csv'),report.records);
leo_write_struct_csv(fullfile(directory,'method_summary.csv'),report.summary);
leo_write_struct_csv(fullfile(directory,'conditional_throughput_bounds.csv'),conditional);
leo_write_struct_csv(fullfile(directory,'stopping_summary.csv'),leo_stopping_rows(report));
stages=struct([]); users=struct([]); schedules=struct([]); primaryUsers=struct([]); primarySchedules=struct([]);
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    solution=report.solutions{j}; exact=leo_evaluate_service(e.problemData,solution.x);
    primary=leo_evaluate_service(e.problemData,solution.stage1.x);
    for phase=1:2
        stage=solution.(sprintf('stage%d',phase)); iterations=NaN;
        if isfield(stage,'rounds'), iterations=stage.rounds; elseif isfield(stage,'iterations'), iterations=stage.iterations; end
        floorValue=0; if phase==2, floorValue=r.stage1Fairness; end
        row=struct('method',r.method,'seed',r.seed,'phase',phase,'initialFairness',stage.initialService.fairness, ...
            'savedFairness',stage.service.fairness,'totalBits',stage.service.totalBits,'fixedFairnessFloor',floorValue, ...
            'nativeIterations',iterations,'status',stage.status);
        stages=leo_append_struct(stages,row);
    end
    for i=1:e.problemData.shape(1)
        row=struct('method',r.method,'seed',r.seed,'user',i,'targetBits',e.problemData.qosTargetBits(i), ...
            'serviceBits',exact.userBits(i),'demandRatio',exact.demandRatio(i)); users=leo_append_struct(users,row);
        row.serviceBits=primary.userBits(i); row.demandRatio=primary.demandRatio(i);
        primaryUsers=leo_append_struct(primaryUsers,row);
        for m=1:e.problemData.shape(2)
            row=struct('method',r.method,'seed',r.seed,'user',i,'resource',m,'selected',solution.x(i,m),'beam',e.problemData.beamIndex(i,m));
            schedules=leo_append_struct(schedules,row);
            row.selected=solution.stage1.x(i,m); primarySchedules=leo_append_struct(primarySchedules,row);
        end
    end
end
leo_write_struct_csv(fullfile(directory,'stages.csv'),stages);
leo_write_struct_csv(fullfile(directory,'user_service.csv'),users);
leo_write_struct_csv(fullfile(directory,'schedules.csv'),schedules);
leo_write_struct_csv(fullfile(directory,'stage1_user_service.csv'),primaryUsers);
leo_write_struct_csv(fullfile(directory,'stage1_schedules.csv'),primarySchedules);
data=leo_v12_trace_data(report); leo_write_struct_csv(fullfile(directory,'search_checkpoints.csv'),data.progress);
fairSummary=struct('fairnessLower',certificate.lower,'fairnessUpper',certificate.upper,'absoluteGap',certificate.absoluteGap, ...
    'relativeGap',certificate.relativeGap,'gapTargetMet',certificate.gapTargetMet,'status',certificate.status, ...
    'nodesProcessed',certificate.nodesProcessed,'openNodes',certificate.openNodeCount,'pricingComplete',certificate.pricingComplete, ...
    'elapsedSeconds',certificate.elapsedSeconds,'scope',certificate.scope);
leo_write_struct_csv(fullfile(directory,'fairness_certificate_summary.csv'),fairSummary);
leo_write_struct_csv(fullfile(directory,'fairness_certificate_nodes.csv'),certificate.branchTrace);
certificateUsers=struct([]); certificateSchedule=struct([]);
for i=1:e.problemData.shape(1)
    row=struct('user',i,'targetBits',e.problemData.qosTargetBits(i),'serviceBits',certificate.incumbentService.userBits(i), ...
        'demandRatio',certificate.incumbentService.demandRatio(i)); certificateUsers=leo_append_struct(certificateUsers,row);
    for m=1:e.problemData.shape(2)
        row=struct('user',i,'resource',m,'selected',certificate.incumbentX(i,m)); certificateSchedule=leo_append_struct(certificateSchedule,row);
    end
end
leo_write_struct_csv(fullfile(directory,'fairness_certificate_users.csv'),certificateUsers);
leo_write_struct_csv(fullfile(directory,'fairness_certificate_schedule.csv'),certificateSchedule);
save(fullfile(directory,'benchmark.mat'),'report','-v7');
specs=leo_build_v12_specs(report,data); fid=fopen(fullfile(directory,[release.prefix,'_specs.json']),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
files={}; if render, files=leo_render_plot_specs(specs,directory); end
[~,diagnosticFiles]=run_leo_v12_diagnostics(report,directory,render); files=[files,diagnosticFiles];
write_summary(report,directory);
for j=1:numel(report.records)
    r=report.records(j);
    fprintf('%s %-24s seed %.0f: s1=%.9g, s2=%.9g, floor=%.9g, total=%.6g Mbit, preserved=%d.\n', ...
        release.tag,leo_method_name(r.method),r.seed,r.stage1Fairness,r.stage2Fairness,r.requiredFairnessFloor,r.totalBits/1e6,r.fairnessPreserved);
end
fprintf('GLOBAL FAIRNESS optimum in [%.9g, %.9g]; %s. Secondary throughput bounds are conditional on each stated floor.\n',certificate.lower,certificate.upper,certificate.status);
end
function write_summary(report,directory)
c=report.fairnessCertificate; fid=fopen(fullfile(directory,'RESULTS.md'),'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
release=leo_lexicographic_release(report);
fprintf(fid,'# %s: uncapped lexicographic fairness\n\n',release.version);
fprintf(fid,'Primary: maximize min_i G_i/q_i with no cap at 1. Secondary: maximize sum_i G_i while every ratio remains >= the attained stage-1 level.\n\n');
fprintf(fid,'Global original-model fairness interval: [%.12g, %.12g]; status %s; gap target met %d. Extra certificate schedules are separate from method scores.\n\n',c.lower,c.upper,c.status,c.gapTargetMet);
fprintf(fid,'| Method | Search seed | Stage-1 fairness | Final fairness | Preserved floor | Final service (Mbit/period) | Stage-1 confirmed within certificate tolerance |\n|---|---:|---:|---:|---:|---:|---:|\n');
for j=1:numel(report.records)
    r=report.records(j); fprintf(fid,'| %s | %.0f | %.9g | %.9g | %.9g | %.9g | %d |\n',leo_method_name(r.method),r.seed,r.stage1Fairness,r.stage2Fairness,r.requiredFairnessFloor,r.totalBits/1e6,r.stage1CertificateConfirmed);
end
fprintf(fid,'\nFairness is the primary comparison. Total service at different attained floors solves different conditional problems; do not rank it as one common throughput objective.\n');
fprintf(fid,'A time-limited stage-1 result is an attained feasible fairness value, not a proven global maximum unless the fairness certificate closes its gap to the stated tolerance.\n');
fprintf(fid,'Per-stage search stopping details are in stopping_summary.csv. target_gap uses a valid original-model upper bound; stagnation only reports a lack of meaningful improvement.\n');
fprintf(fid,'V10/V11 optimized full-QoS-then-sum service and their scores/bounds are not reused as V12 lexicographic optimality evidence.\n');
end
