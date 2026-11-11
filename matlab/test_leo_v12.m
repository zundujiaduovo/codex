function test_leo_v12()
%TEST_LEO_V12 独立二元枚举：未封顶公平、阶段2保持、全域公平界和条件吞吐界。
[problem,high,balanced]=fixture(); data=problem.data;
a=problem.evaluate(high); b=problem.evaluate(balanced);
assert(abs(a.fairness-1.1)<1e-12 && abs(b.fairness-4)<1e-12);
assert(a.totalBits>b.totalBits && a.qosCompletion==1 && b.qosCompletion==1);
assert(leo_service_is_better(b,a,'fairness',0));
assert(~leo_service_is_better(a,b,'throughput',b.fairness));
stage2=leo_form_stage2(data,balanced); assert(problem.stage1.ub(end)>4 && stage2.s0==4);
[best,bestX]=enumerate(problem); assert(abs(best.fairness-4)<1e-12 && abs(best.totalBits-8)<1e-12);
exact=leo_exhaustive_search(problem,struct('verbose',false));
assert(exact.completed && abs(exact.fairness-4)<1e-12 && abs(exact.totalBits-8)<1e-12);
old=data; old.objectiveMode='full_qos_sum';
oldHigh=leo_evaluate_service(old,high); oldBalanced=leo_evaluate_service(old,balanced);
assert(oldHigh.fairness==1 && oldBalanced.fairness==1);
assert(leo_service_is_better(oldHigh,oldBalanced,'fairness',0));
% s辅助变量和原模型界均允许大于1；不同乘子必须覆盖独立枚举最优值。
cache=leo_prepare_upper_bounds(data);
for lambda=[zeros(2,1),[.1;.7],ones(2,1)/2,[1;0],[0;1],[2;3]]
    upper=leo_original_upper_bound(data,cache,lambda,'fairness'); assert(upper.value>=4-1e-10);
end
[~,sAux]=leo_price_weights(data,[.1;.1],'fairness',0); assert(sAux>4);
leo_update_prices([.5;.5],[1;2],[1;1],sAux,.1);
proxy=leo_v12_build_service_surrogates(problem,'current_schedule',high);
milp=leo_form_proxy_milp(data,proxy.lower,'fairness',0); assert(milp.ub(end)>4);
% 原式Tabu与两种V12内层均保持阶段1公平；初始化已经>1也继续公平搜索。
options=leo_method_options(struct('maxSeconds',10,'fairnessRounds',3,'throughputRounds',3, ...
    'originalSearchRounds',4,'sbSteps',30,'sbTrajectories',4,'localRestarts',3, ...
    'randomInitialSchedules',0,'verbose',false));
before=rng;
for name={'original_tabu','sb_v12_lexicographic','local_v12_lexicographic'}
    result=leo_run_benchmark_method(problem,[],high,name{1},options);
    assert(isequal(rng,before));
    assert(result.stage1.service.fairness>1 && result.fairnessFloor==result.stage1.service.fairness);
    assert(all(result.service.demandRatio>=result.stage1.service.fairness));
    assert(result.service.totalBits>=result.stage1.service.totalBits);
    assert(~strcmp(result.stage1.status,'full_qos_already_met'));
end
report=make_report(problem,{high,bestX});
certificate=leo_fairness_certificate(report,struct('maxSeconds',10,'maxNodes',128,'relativeGap',1e-7,'absoluteGap',1e-7,'verbose',false));
assert(certificate.lower<=4+1e-9 && certificate.upper>=4-1e-9 && certificate.gapTargetMet);
assert(certificate.upper-certificate.lower<1e-6);
for j=1:numel(certificate.branchTrace), assert(certificate.branchTrace(j).fairnessUpper>=4-1e-9); end
conditional=leo_theory_bound(report,struct('fairnessFloor',4,'maxSeconds',10,'relativeGap',1e-7,'absoluteGapBits',1e-8,'verbose',false));
assert(~conditional.recordFeasible(1) && conditional.recordFeasible(2));
assert(conditional.upperBits>=8-1e-8 && abs(conditional.lowerBits-8)<1e-8);
rejected=false;
try, leo_theory_bound(report,struct('maxSeconds',0)); catch err, rejected=strcmp(err.identifier,'leo:conditionalFloorRequired'); end
assert(rejected);
% 有风险余量、异质需求时仍用原G枚举，避免只验证零余量的特例。
adjusted=data; adjusted.qosTargetBits=[.7;1.2];
adjusted.design.serviceScale=[.8;.9]; adjusted.design.serviceMarginBits=[.2;.3];
adjusted=rmfield(adjusted,'fairnessUpperLimit');
adjusted.fairnessUpperLimit=leo_fairness_limit(adjusted);
adapted=as_problem(adjusted); [truth,x]=enumerate(adapted);
cert=leo_fairness_certificate(make_report(adapted,{x}),struct('maxSeconds',10,'maxNodes',128,'relativeGap',1e-7,'absoluteGap',1e-7,'verbose',false));
assert(cert.upper>=truth.fairness-1e-9 && cert.lower<=truth.fairness+1e-9);
% 3用户2块L=1：整数最优公平为0，分数松弛>0，必须分支或保留差距。
zero=zero_fixture(); [truth,x]=enumerate(zero); assert(truth.fairness==0);
cert=leo_fairness_certificate(make_report(zero,{x}),struct('maxSeconds',10,'maxNodes',128,'verbose',false));
assert(cert.lower==0 && cert.upper<1e-6 && cert.gapTargetMet && cert.nodesProcessed>1);
% s0=0时G的逐用户截断不可丢失；旧sum(A)-sum(margin)会错误低估上界。
clipped=data; clipped.shape=[2,1]; clipped.available=true(2,1); clipped.beamIndex=[1;2];
clipped.slotToResource=1; clipped.dataDurationS=1; clipped.hard.A=sparse([1,1]); clipped.hard.rhs=1;
clipped.hard.upper=ones(2,1); clipped.hard.lower=zeros(2,1); clipped.hard.integerIndices=(1:2).';
clipped.design.signalW=2.^[10;8]-1; clipped.design.noiseW=ones(2,1); clipped.design.beamPowerW=zeros(2,2,1);
clipped.design.serviceScale=ones(2,1); clipped.design.serviceMarginBits=[2;3];
clipped=rmfield(clipped,'fairnessUpperLimit'); cp=as_problem(clipped); [truth,x]=enumerate(cp);
zeroBound=leo_theory_bound(make_report(cp,{x}),struct('fairnessFloor',0,'maxSeconds',0,'verbose',false));
assert(zeroBound.upperBits>=truth.totalBits-1e-9 && ~zeroBound.pricingComplete);
% 同波束候选、真实组间干扰、异质需求和风险余量：从空日程启动独立证书。
interference=interference_fixture(); [truth,x]=enumerate(interference); %#ok<ASGLU>
empty=make_report(interference,{false(interference.data.shape)});
cert=leo_fairness_certificate(empty,struct('maxSeconds',15,'maxNodes',512,'relativeGap',1e-7,'absoluteGap',1e-7,'verbose',false));
assert(cert.upper>=truth.fairness-1e-8 && cert.lower<=truth.fairness+1e-8);
assert(cert.gapTargetMet && cert.lower>0);
for j=1:numel(cert.branchTrace), assert(cert.branchTrace(j).fairnessUpper>=truth.fairness-1e-8); end
floorValue=.85*truth.fairness; truthTotal=-Inf;
for code=0:2^prod(interference.data.shape)-1
    candidate=reshape(logical(bitget(code,1:prod(interference.data.shape))),interference.data.shape);
    if any(interference.data.hard.A*double(candidate(:))>interference.data.hard.rhs), continue; end
    service=interference.evaluate(candidate);
    if all(service.demandRatio>=floorValue), truthTotal=max(truthTotal,service.totalBits); end
end
bound=leo_theory_bound(empty,struct('fairnessFloor',floorValue,'maxSeconds',15,'maxNodes',512,'relativeGap',1e-7,'absoluteGapBits',1e-5,'verbose',false));
assert(bound.upperBits>=truthTotal-1e-5 && bound.lowerBits<=truthTotal+1e-5 && bound.gapTargetMet);
% 历史QoS开关即便误设为true，也不能截断V12目标或强制门槛回到1。
strict=data; strict.requireFullQos=true; assert(~leo_requires_full_qos(strict));
historical=rmfield(old,'objectiveMode'); assert(~leo_is_lexicographic(historical));
historicalScore=leo_evaluate_service(historical,balanced); assert(historicalScore.fairness==1);
% 通用benchmark入口也随模型选择V12默认方法，不能默认误派到冻结旧目标引擎。
mock=struct('problem',problem,'parameters',struct(),'xExample',high,'surrogate',[], ...
    'timings',struct('physicalProblemSeconds',0,'proxySeconds',0));
benchOptions=struct('seeds',7,'budgetSeconds',10,'exhaustive',false,'makePlots',false, ...
    'diagnosticSurrogates',false,'verbose',false,'method',options);
benchmark=leo_benchmark_case(mock,benchOptions);
assert(all(strcmp({benchmark.records.status},'completed')));
assert(any(strcmp(benchmark.options.methods,'sb_v12_lexicographic')) && ~any(strcmp(benchmark.options.methods,'sb_v8_blockwise')));
legacyOptions=leo_benchmark_options(struct(),old); assert(any(strcmp(legacyOptions.methods,'sb_v8_blockwise')));
fprintf('PASS: V12 uncapped lexicographic counterexample, >1 phase search, strict stage-2 floor, MILP cap removal, original-model bounds, risk margins and zero-fairness branching.\n');
end
function [problem,high,balanced]=fixture()
p=leo_default_parameters(); p.statistics.serviceModel='slot_union'; p.users.layout='reference32';
p.system.K=2; p.system.maxStreams=1; p.system.bandwidthHz=1; p.system.qosTargetBits=1;
p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); r=leo_build_resources(p); b.available=true(2,2); b.index=repmat((1:2).',1,2);
d=struct('serviceModel','slot_union','signalW',2.^[10,4;4,1.1]-1,'noiseW',ones(2,2),'beamPowerW',zeros(2,2,2));
problem=leo_form_problem(p,r,b,d); high=logical(eye(2)); balanced=logical(fliplr(eye(2)));
end
function [best,xbest]=enumerate(problem)
data=problem.data; best=problem.evaluate(false(data.shape)); xbest=false(data.shape);
for code=0:2^prod(data.shape)-1
    x=reshape(logical(bitget(code,1:prod(data.shape))),data.shape);
    if any(x(:)>data.hard.upper) || any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
    s=problem.evaluate(x);
    if leo_service_is_better(s,best,'fairness',0), best=s; xbest=x; end
end
end
function p=as_problem(data)
p=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
p.precheck=leo_precheck_positive_fairness(data);
end
function report=make_report(problem,schedules)
report=struct('problemData',problem.data,'parameters',struct(),'records',struct([]),'solutions',{{}});
for j=1:numel(schedules)
    service=problem.evaluate(schedules{j}); solution=struct('x',schedules{j},'service',service,'stage1',struct('x',schedules{j},'service',service));
    report.records=leo_append_struct(report.records,struct('method',sprintf('fixture%d',j),'seed',j,'status','completed'));
    report.solutions{j}=solution;
end
end
function problem=zero_fixture()
[source,~,~]=fixture(); data=source.data; data.shape=[3,2]; data.qosTargetBits=ones(3,1); data.referenceBits=3;
data.available=true(3,2); data.beamIndex=repmat((1:3).',1,2); data.hard.A=sparse([1,1,1,0,0,0;0,0,0,1,1,1]);
data.hard.rhs=ones(2,1); data.hard.upper=ones(6,1); data.hard.lower=zeros(6,1); data.hard.integerIndices=(1:6).';
data.design.signalW=ones(3,2); data.design.noiseW=ones(3,2); data.design.beamPowerW=zeros(3,3,2);
data=rmfield(data,'fairnessUpperLimit'); data.fairnessUpperLimit=leo_fairness_limit(data); problem=as_problem(data);
end
function problem=interference_fixture()
p=leo_default_parameters(); p.statistics.serviceModel='slot_union'; p.system.K=4;
p.system.maxStreams=2; p.system.bandwidthHz=1e6; p.system.qosTargetBits=[.3;.4;.5;.6]*1e6;
p.time.nSlots=4; p.time.blockSlots=2; p.time.slotDurationS=.5;
p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(4,2); b.index=repmat([1;1;2;3],1,2);
d.signalW=[1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW=repmat([1,2,1.5,3],4,1); d.beamPowerW=zeros(4,3,4); d.serviceModel='slot_union';
d.serviceScale=[.8;.9;.85;.95]; d.serviceMarginBits=[.02;.03;.04;.05]*1e6;
for t=1:4, d.beamPowerW(:,:,t)=[2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem=leo_form_problem(p,r,b,d);
end
