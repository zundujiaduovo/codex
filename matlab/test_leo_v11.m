function test_leo_v11()
%TEST_LEO_V11 手算配对差值/置信区间、缺失、重复种子、RNG及V10日志等价。
o=leo_v11_paired_options(struct('seeds',1:20,'bootstrapSamples',1000));
pairs=struct([]);
for seed=o.seeds
    for baseline={'original_tabu','local_v8_blockwise'}
        p=struct('seed',seed,'baseline',baseline{1},'deltaBits',2,'relativeGainPercent',1,'deltaBudgetBits',3);
        pairs=leo_append_struct(pairs,p);
    end
end
before=rng; s=leo_v11_paired_statistics(pairs,o); assert(isequal(rng,before));
assert(isequaln(s,leo_v11_paired_statistics(pairs,o)));
for j=1:2
    assert(s(j).availablePairs==20 && s(j).wins==20 && s(j).losses==0 && s(j).ties==0);
    assert(s(j).meanDeltaBits==2 && s(j).meanDelta95LowBits==2 && s(j).meanDelta95HighBits==2);
    assert(abs(s(j).signTestTwoSidedP-2/2^20)<1e-15 && abs(s(j).signTestHolmP-4/2^20)<1e-15);
    assert(s(j).meanBudgetDeltaBits==3);
end
% 缺失配对不能当平局或0差值；全平时p=1。单样本CI不可估计。
for j=1:numel(pairs), pairs(j).deltaBits=NaN; pairs(j).deltaBudgetBits=NaN; end
pairs(1).deltaBits=0; s=leo_v11_paired_statistics(pairs,o);
assert(s(1).availablePairs==1 && s(1).missingPairs==19 && s(1).ties==1 && s(1).signTestTwoSidedP==1);
assert(isnan(s(1).meanDelta95LowBits) && s(2).availablePairs==0 && isnan(s(2).meanDeltaBits));
rejected=false;
try, leo_v11_paired_options(struct('seeds',[1,1])); catch, rejected=true; end
assert(rejected);
% 手算非对称胜负：1胜3负，双侧sign概率为0.625。
small=pairs(1:8);
for j=1:8
    small(j).deltaBits=-2; small(j).deltaBudgetBits=NaN;
end
small(1).deltaBits=2; small(2).deltaBits=2;
asymmetric=leo_v11_paired_statistics(small,o);
assert(asymmetric(1).wins==1 && asymmetric(1).losses==3 && abs(asymmetric(1).signTestTwoSidedP-.625)<1e-12);
assert(asymmetric(1).meanDeltaBits==-1 && asymmetric(1).signTestHolmP==1);
duplicate=[small;small(1)]; rejected=false;
try, leo_v11_paired_statistics(duplicate,o); catch, rejected=true; end
assert(rejected);
% 与V10完整日志提取器的性能统计一致；专门覆盖相同时间的阶段/检查点。
problem=fixture(); model=struct('problem',problem,'parameters',struct('seed',1),'xExample',logical(eye(2)), ...
    'surrogate',[],'timings',struct('physicalProblemSeconds',.001,'proxySeconds',0));
b=struct('methods',{{'original_tabu','sb_v8_blockwise','local_v8_blockwise'}},'seeds',7, ...
    'budgetSeconds',20,'verbose',false,'exhaustive',false,'makePlots',false,'diagnosticSurrogates',false, ...
    'method',struct('fairnessRounds',2,'throughputRounds',2,'originalSearchRounds',2, ...
        'sbSteps',20,'sbTrajectories',3,'randomInitialSchedules',0,'localRestarts',2));
report=leo_benchmark_case(model,b);
assert(all(strcmp({report.records.status},'completed')));
report.theory=struct('upperBits',1e9,'lowerBits',1);
a=leo_performance_metrics(leo_collect_plot_data(report));
b=leo_performance_metrics(leo_v11_trace_data(report));
assert(isequaln(a.summary,b.summary) && isequaln(a.targets,b.targets) && isequaln(a.deadlines,b.deadlines));
assert(~report.solutions{1}.usesQuadraticProxy);
assert(strcmp(report.solutions{2}.searchEngine,'V8 frozen cd4ba09') && strcmp(report.solutions{3}.searchEngine,'V8 frozen cd4ba09'));
assert(strcmp(report.solutions{2}.options.innerSolver,'sb') && strcmp(report.solutions{3}.options.innerSolver,'local'));
fprintf('PASS: V11 paired bootstrap/sign/Holm, missing pairs, RNG, duplicate seeds, V10 trace equivalence and matched engine controls.\n');
end
function problem=fixture()
p=leo_default_parameters(); p.system.K=2; p.system.maxStreams=1; p.system.bandwidthHz=1e6;
p.system.qosTargetBits=1e4; p.problem.requireFullQos=true; p.time.nSlots=2; p.time.blockSlots=1;
p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(2,2); b.index=repmat((1:2).',1,2);
d=struct('serviceModel','slot_union','signalW',repmat([10;8],1,2),'noiseW',ones(2,2),'beamPowerW',zeros(2,2,2));
problem=leo_form_problem(p,r,b,d);
end
