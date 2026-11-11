function test_leo_v10()
%TEST_LEO_V10 冻结引擎分派与RNG、手算质量时间指标、缺失/晚达标、非切点误差。
problem=fixture(); x=logical(eye(2));
o=leo_method_options(struct('verbose',false,'maxSeconds',20,'fairnessRounds',2, ...
 'throughputRounds',2,'sbSteps',20,'sbTrajectories',4,'randomInitialSchedules',0, ...
 'recoveryEvaluations',8,'recoveryPasses',1));
before=rng;
for kind={'sb','local'}
    name=[kind{1},'_v8_blockwise'];
    r=leo_run_benchmark_method(problem,[],x,name,o);
    assert(isequal(rng,before) && strcmp(r.searchEngine,'V8 frozen cd4ba09'));
    assert(~isfield(r.options,'sbPerturbedSeeds') && ~isfield(r.options,'jointCandidateSearch'));
    assert(r.options.blockwiseOriginalAccept && r.options.sbSteps==20);
    direct=leo_v8_solve_schedule(problem,[],r.options,x);
    assert(isequal(r.x,direct.x) && isequal(r.stage2.history.priceX,direct.stage2.history.priceX));
    assert(isequal(r.stage2.history.lambda,direct.stage2.history.lambda));
end
defaults=leo_benchmark_options();
assert(numel(defaults.methods)==8 && any(strcmp(defaults.methods,'sb_v8_blockwise')));
assert(any(strcmp(defaults.methods,'local_v8_blockwise')) && ~any(strcmp(defaults.methods,'price_sb_joint')));

% 手算：A平均界差10.5%，B提前结束后其已返回解仍可用，平均界差6.125%。
data=struct('schemaVersion',1,'methods',{{'A','B','failed'}},'seeds',13,'representativeSeed',13, ...
 'budgetSeconds',10,'theoryBounds',struct('upperBits',100,'lowerBits',99.9));
template=struct('method','A','seed',13,'status','completed','fullQosFeasible',true, ...
 'fairness',1,'totalBits',99.5,'worstDemandRatio',1.2,'jainFairness',.9);
data.records=repmat(template,3,1); data.records(2).method='B'; data.records(2).totalBits=97;
data.records(3).method='failed'; data.records(3).status='failed'; data.records(3).fullQosFeasible=false;
data.progress=struct([]);
add('A',[2,6,6,10],[80,90,99,99.5]); add('B',[1,4,5],[85,96,97]);
options=struct('gapTargetsPercent',[5,2,1,.5],'deadlinesSeconds',[1,3,6,10,12]);
m=leo_performance_metrics(data,options);
assert(abs(m.summary(1).timeAverageGapPercent-10.5)<1e-10);
assert(abs(m.summary(2).timeAverageGapPercent-6.125)<1e-10);
assert(all([m.summary.windowStartSeconds]==2));
a=m.targets(strcmp({m.targets.method},'A') & [m.targets.targetGapPercent]==1);
assert(a.hitWithinBudget && a.firstRecordedHitSeconds==6);
b=m.targets(strcmp({m.targets.method},'B') & [m.targets.targetGapPercent]==1);
assert(~b.hitWithinBudget && isnan(b.firstRecordedHitSeconds));
early=m.deadlines(strcmp({m.deadlines.method},'A') & [m.deadlines.deadlineSeconds]==1);
assert(isnan(early.certifiedBits));
held=m.deadlines(strcmp({m.deadlines.method},'B') & [m.deadlines.deadlineSeconds]==10);
assert(held.certifiedBits==97);
assert(all(isnan([m.targets(strcmp({m.targets.method},'failed')).firstRecordedHitSeconds])));
assert(all(strcmp({m.deadlines([m.deadlines.deadlineSeconds]>10).status},'outside_budget')));
late=data; at=find(strcmp({late.progress.method},'A'),1,'last'); late.progress(at).seconds=10.01;
q=leo_performance_metrics(late,options);
a=q.targets(strcmp({q.targets.method},'A') & [q.targets.targetGapPercent]==.5);
assert(~a.hitWithinBudget && strcmp(a.status,'reached_after_budget'));
absent=data; absent.theoryBounds=struct([]); q=leo_performance_metrics(absent,options);
assert(isnan(q.summary(1).timeAverageGapPercent) && all(isnan([q.targets.firstRecordedHitSeconds])));
directory=tempname; cleanup=onCleanup(@() rmdir(directory,'s')); %#ok<NASGU>
[m,files]=run_leo_performance_metrics(data,directory,options,false);
assert(isempty(files) && exist(fullfile(directory,'time_to_quality.csv'),'file')==2);

% 固定末次代理：参考点误差接近0不能掩盖邻域探针的非零误差。
result=struct('x',true(2),'service',problem.evaluate(true(2)));
result.stage2=struct('proxy',leo_v8_build_service_surrogates(problem,'current_schedule',true(2)), ...
 'history',struct());
report=struct('problemData',problem.data,'solutions',{{result}}, ...
 'records',struct('method','sb_v8_blockwise','seed',13,'status','completed'));
[probes,summary]=leo_export_proxy_audit(report,directory,12);
assert(any([probes.isReferencePoint]) && summary.offReferenceProbes>0);
assert(max([probes([probes.isReferencePoint]).clippedUnderestimatePercent])<1e-8);
assert(summary.maxObservedClippedUnderestimatePercent>0);
fprintf('PASS: frozen V8 dispatch/RNG, paired controls, hand-calculated quality/time metrics, missing and late targets, held returns and off-reference proxy audit.\n');
    function add(method,times,values)
        for k=1:numel(times)
            row=struct('method',method,'seed',13,'seconds',times(k),'fairness',1,'totalBits',values(k),'kind','test');
            if isempty(data.progress), data.progress=row; else, data.progress(end+1,1)=row; end
        end
    end
end
function problem=fixture()
p=leo_default_parameters(); p.problem.objectiveMode='full_qos_sum'; p.statistics.serviceModel='slot_union'; p.system.K=2;
p.system.maxStreams=2; p.system.bandwidthHz=1; p.system.qosTargetBits=1; p.problem.requireFullQos=true;
p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); resources=leo_build_resources(p); beams.available=true(2); beams.index=repmat([1;2],1,2);
design.signalW=[3,7;7,3]; design.noiseW=ones(2); design.beamPowerW=.3*ones(2,2,2);
problem=leo_form_problem(p,resources,beams,design);
end
