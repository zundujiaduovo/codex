function test_leo_v12_validation()
%TEST_LEO_V12_VALIDATION 独立枚举、真实计数、旧日志缺失、贪婪增补及迭代单位。
[model,method]=fixture(); before=rng;
o=struct('methods',{{'original_tabu','sb_v12_lexicographic','local_v12_lexicographic'}}, ...
    'seeds',11,'budgetSeconds',10,'method',method,'exhaustive',false,'makePlots',false, ...
    'diagnosticSurrogates',false,'verbose',false,'outputDirectory','');
report=leo_benchmark_case(model,o); assert(all(strcmp({report.records.status},'completed')) && isequal(rng,before));
data=leo_v12_diagnostic_data(report); assert(numel(data.workload)==3 && numel(data.phases)==6);
for j=1:numel(report.records)
    for phase=1:2
        stage=report.solutions{j}.(sprintf('stage%d',phase));
        rows=data.iterations(strcmp({data.iterations.method},report.records(j).method) & [data.iterations.phase]==phase);
        assert(rows(1).nativeIteration==0 && rows(1).fairness==stage.initialService.fairness);
        if isfield(stage,'rounds'), count=stage.rounds; else, count=stage.iterations; end
        assert(max([rows.nativeIteration])==count && all(diff([rows.nativeIteration])>=0));
        assert(rows(end).fairness==stage.service.fairness && rows(end).totalBits==stage.service.totalBits);
    end
end
assert(strcmp(data.workload(1).phase1Kind,'tabu_round') && strcmp(data.workload(2).phase1Kind,'price_round_attempt'));
assert(data.workload(1).recordedOriginalCandidateScores==report.solutions{1}.evaluations);
assert(data.workload(2).resourceSolves>0 && data.workload(2).denseDynamicsTerms>0);
% 本例每块3个候选/3波束/L=2：2个容量松弛位，N=5，R=3。
assert(data.workload(2).maxQuboBits==5);
assert(data.workload(2).denseDynamicsTerms==25*method.sbTrajectories*data.workload(2).sbIntegrationSteps);
assert(data.workload(3).denseDynamicsTerms==0 && data.workload(3).sbIntegrationSteps==0);
assert(data.workload(2).innerSeconds>=0 && data.workload(2).proxyBuildAndRefreshSeconds>=0);
legacy=report;
for j=2:3
    for name={'workloadSchemaVersion','initialProxySeconds','stage2ProxySeconds','upperBoundPreparationSeconds'}
        if isfield(legacy.solutions{j},name{1}), legacy.solutions{j}=rmfield(legacy.solutions{j},name{1}); end
    end
    for phase=1:2
        field=sprintf('stage%d',phase); h=legacy.solutions{j}.(field).history;
        fields=intersect(fieldnames(h),{'innerSeconds','originalSelectionSeconds','recoverySeconds','proxyRefreshSeconds','maxQuboBits','sbTrajectorySteps','denseDynamicsTerms'});
        legacy.solutions{j}.(field).history=rmfield(h,fields);
    end
end
old=leo_v12_diagnostic_data(legacy);
assert(isnan(old.workload(2).denseDynamicsTerms) && isnan(old.workload(2).innerSeconds));
assert(old.workload(3).denseDynamicsTerms==0 && isnan(old.workload(3).proxyBuildAndRefreshSeconds));
root=tempname; mkdir(root); cleanup=onCleanup(@() finish(root)); %#ok<NASGU>
report.fairnessCertificate=struct('lower',max([report.records.fairness]),'upper',leo_fairness_limit(report.problemData), ...
    'options',struct('absoluteGap',1e-6,'relativeGap',1e-5));
save(fullfile(root,'benchmark.mat'),'report','-v7');
experiment=struct('version','V12 uncapped lexicographic','problemData',model.problem.data, ...
    'modelSnapshot',rmfield(model,'problem'),'protocol',struct('seeds',11,'budgetSeconds',10,'method',method));
save(fullfile(root,'experiment.mat'),'experiment','-v7');
[a,files]=run_leo_v12_diagnostics(root,root,false); assert(isempty(files) && numel(a.iterations)==numel(data.iterations));
specs=jsondecode(fileread(fullfile(root,'v12_diagnostic_specs.json'))); assert(numel(specs)==2);
assert(strcmp(specs(1).panels(1).xlabel,'Native outer iteration (method-specific units)'));
saved=load(fullfile(root,'benchmark.mat'),'report'); assert(isequaln(saved.report,report));
[combined,~]=run_leo_v12_greedy_control(root,struct(),false);
assert(numel(combined.records)==4 && strcmp(combined.records(end).method,'original_greedy'));
assert(isequal([combined.records(1:3).totalBits],[report.records.totalBits]));
greedy=combined.solutions{end}; assert(isequal(greedy.initial.x,report.solutions{1}.initial.x));
assert(all(greedy.service.demandRatio>=greedy.stage1.service.fairness));
gd=leo_v12_diagnostic_data(combined);
assert(gd.workload(end).recordedOriginalCandidateScores==greedy.evaluations);
again=run_leo_v12_greedy_control(root,struct(),false);
assert(again.records(end).endToEndSeconds==combined.records(end).endToEndSeconds);
parent=report.problemData; before=rng;
audit=run_leo_v12_proxy_control(report,struct('resources',1,'maxUsers',2,'seeds',[3,5], ...
    'callBudgetSeconds',1,'outputDirectory',fullfile(root,'proxy')),false);
assert(isequal(rng,before),'Proxy diagnostics changed the caller RNG.');
assert(isequaln(report.problemData,parent),'Proxy diagnostics mutated the original model.');
assert(numel(audit.exact)==4 && numel(audit.runs)==16 && all([audit.exact.domainRestricted]));
assert(all([audit.runs.innerProxyLoss]>=0));
assert(all([audit.runs.combinedOriginalLossPercent]<=[audit.runs.combinedLossUpperBoundPercent]+1e-7));
% 对每一确切域单独用全二元位串重算原式和代理最优，不复用组生成器。
for j=1:numel(audit.exact)
    e=audit.exact(j); ri=find(strcmp(audit.referenceNames,e.reference)); reference=audit.referenceSchedules{ri};
    at=find(strcmp({audit.groups.reference},e.reference) & strcmp({audit.groups.phase},e.phase) & strcmp({audit.groups.solver},'exact_proxy'),1);
    ids=sscanf(audit.groups(at).domainUsers,'%d'); restricted=parent;
    restricted.available(:,1)=false; restricted.available(ids,1)=true; restricted.hard.upper=double(restricted.available(:));
    problem=struct('data',parent,'evaluate',@(x) leo_evaluate_service(parent,x));
    proxy=leo_v12_build_service_surrogates(problem,'current_schedule',reference);
    weights=audit.weights(strcmp({audit.weights.reference},e.reference) & strcmp({audit.weights.phase},e.phase) & [audit.weights.resource]==e.resource);
    w=zeros(3,1); w([weights.user])=[weights.serviceWeight]; q=leo_build_resource_qubo(restricted,proxy.lower,1,w,method);
    po=-Inf; oo=-Inf; legal=0;
    for code=0:7
        group=logical(bitget(code,1:3)).';
        if any(group & ~restricted.available(:,1)) || sum(group)>2, continue; end
        legal=legal+1; x=double(group(q.userIds));
        po=max(po,q.A.'*x-x.'*q.B*x/2); oo=max(oo,w.'*leo_resource_service(restricted,1,group));
    end
    assert(legal==e.legalGroups && abs(po-e.exactProxyWeightedScore)<1e-9 && abs(oo-e.exactOriginalWeightedScore)<1e-9);
end
fprintf('PASS: V12 native iterations, exact recorded work, unknown legacy metrics, original greedy supplement/cache, RNG, restricted-domain independent proxy/original enumeration and solver-loss bounds.\n');
end
function [model,method]=fixture()
p=leo_v12_parameters(); p.system.K=3; p.system.maxStreams=2; p.system.bandwidthHz=1e6;
p.system.qosTargetBits=[.4;.5;.6]*1e6; p.problem.referenceBits=[]; p.statistics.serviceModel='slot_union';
p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); r=leo_build_resources(p); b.available=true(3,2); b.index=repmat((1:3).',1,2);
d=struct('serviceModel','slot_union','signalW',[4,6;5,3;3,7],'noiseW',ones(3,2),'beamPowerW',zeros(3,3,2));
d.beamPowerW(:,:,1)=[0,.8,1;.6,0,.9;.7,1.1,0]; d.beamPowerW(:,:,2)=[0,.4,.8;1,0,.5;.6,.7,0];
d.serviceScale=[.8;.9;.85]; d.serviceMarginBits=[.1;.15;.12]*1e6;
problem=leo_form_problem(p,r,b,d);
model=struct('problem',problem,'parameters',p,'resources',r,'beams',b,'design',d,'surrogate',[], ...
    'xExample',logical(problem.precheck.witness),'timings',struct('physicalProblemSeconds',0,'proxySeconds',0));
method=leo_method_options(struct('fairnessRounds',2,'throughputRounds',2,'originalSearchRounds',3, ...
    'sbSteps',20,'sbTrajectories',3,'localRestarts',2,'polishMoves',2,'randomInitialSchedules',0, ...
    'recoveryEvaluations',20,'recoveryPasses',2,'verbose',false));
end
function finish(root)
if exist(root,'dir')==7, rmdir(root,'s'); end
end
