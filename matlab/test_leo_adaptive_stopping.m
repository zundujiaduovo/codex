function test_leo_adaptive_stopping()
%TEST_LEO_ADAPTIVE_STOPPING 独立枚举校准近优，确定性时钟校验停滞，四方法真实分派。
o=leo_method_options(struct('stopping',struct('enabled',true)));
s=struct('fairness',99,'normalizedThroughput',.99);
[state,reason]=leo_search_stopping(o,'fairness',s,100,0,0);
assert(strcmp(reason,'target_gap') && state.nearOptimalCertified && state.relativeGap==.01);
s.fairness=98.9; [state,reason]=leo_search_stopping(o,'fairness',s,100,0,0);
assert(isempty(reason) && ~state.nearOptimalCertified);
% 多个小改进累计超过0.01%也重置时钟；每轮微小差异不会错误地无限续期。
s.fairness=50; [state,~]=leo_search_stopping(o,'fairness',s,100,0,0);
s.fairness=50.002; [state,reason]=leo_search_stopping(o,'fairness',s,100,5,1,state); assert(isempty(reason));
s.fairness=50.004; [state,~]=leo_search_stopping(o,'fairness',s,100,10,2,state);
assert(state.lastImprovementSeconds==0);
s.fairness=50.006; [state,~]=leo_search_stopping(o,'fairness',s,100,15,3,state);
assert(state.lastImprovementSeconds==15);
[state,reason]=leo_search_stopping(o,'fairness',s,100,34,4,state); assert(isempty(reason));
[state,reason]=leo_search_stopping(o,'fairness',s,100,35,5,state);
assert(strcmp(reason,'stagnation') && ~state.nearOptimalCertified);
[~,reason]=leo_search_stopping(o,'fairness',s,100,100,2,state); assert(isempty(reason)); % 最少迭代数
s.fairness=1.2; [state,~]=leo_search_stopping(o,'throughput',s,2,0,0);
s.fairness=1.9; [state,reason]=leo_search_stopping(o,'throughput',s,2,20,3,state);
assert(strcmp(reason,'stagnation') && ~state.nearOptimalCertified); % 阶段2看总服务，不看公平增长
off=leo_method_options(); [state,~]=leo_search_stopping(off,'fairness',s,2,0,0);
[~,reason]=leo_search_stopping(off,'fairness',s,2,1000,1000,state); assert(isempty(reason));
[state,reason]=leo_search_stopping(o,'fairness',s,Inf,0,0); assert(~state.nearOptimalCertified && isempty(reason));
for bad={struct('relativeGap',1),struct('patienceSeconds',0),struct('minIterations',.5),struct('unknown',1)}
    failed=false; try, leo_stopping_options(bad{1}); catch, failed=true; end; assert(failed);
end
assert(~isfield(leo_method_options(),'stopping'),'Legacy protocols must not gain new default fields.');
% 四方法均从原式最优见证出发，在任何搜索迭代前识别原模型有效界闭合。
model=fixture(false); [truth,~]=oracle(model.problem);
method=leo_method_options(struct('maxSeconds',5,'randomInitialSchedules',0, ...
    'fairnessRounds',50,'throughputRounds',50,'originalSearchRounds',50,'sbSteps',10, ...
    'sbTrajectories',2,'localRestarts',2,'recoveryEvaluations',4,'polishMoves',2,'verbose',false, ...
    'stopping',struct('enabled',true)));
before=rng; report=leo_benchmark_case(model,struct('methods',{{'Tabu','SB','Local','Greedy'}}, ...
    'seeds',5,'budgetSeconds',5,'method',method,'exhaustive',false,'makePlots',false, ...
    'diagnosticSurrogates',false,'verbose',false));
assert(isequal(rng,before) && all(strcmp({report.records.status},'completed')));
assert(isequal({report.records.method},{'Tabu','SB','Local','Greedy'}));
for j=1:4
    sol=report.solutions{j}; assert(sol.stage1.service.fairness==truth && all(sol.service.demandRatio>=truth));
    assert(sol.stage1.stopping.nearOptimalCertified && sol.stage2.stopping.nearOptimalCertified);
    assert(report.records(j).stage1NearOptimal && report.records(j).stage2NearOptimal);
    assert(all(ismember({sol.stage1.status,sol.stage2.status},{'target_gap','bound_gap'})));
    assert(numel(sol.stage1.history.elapsedSeconds)<=1 && numel(sol.stage2.history.elapsedSeconds)<=1);
end
rows=leo_stopping_rows(report); assert(numel(rows)==8 && all([rows.nearOptimalCertified]));
% 真最优略高于共同初值：验证实际求解器在非零但<1%差距时停止，而非只测精确闭合。
near=fixture(false,true); [truth,~]=oracle(near.problem);
for name={'Tabu','SB','Local','Greedy'}
    sol=leo_run_benchmark_method(near.problem,[],near.xExample,name{1},method);
    assert(strcmp(sol.stage1.status,'target_gap') && strcmp(sol.stage2.status,'target_gap'));
    assert(sol.stage1.service.fairness<truth && sol.stage1.service.fairness>=.99*truth);
    assert(sol.stage1.stopping.relativeGap>0 && sol.stage1.stopping.relativeGap<=.01);
    assert(sol.stage1.stopping.upper>=truth-1e-12 && all(sol.service.demandRatio>=sol.fairnessFloor));
end
% 上界松、已知整数最优的实例：停滞必须保留非零差距，且先公平后吞吐。
model=fixture(true); [truth,~]=oracle(model.problem);
method.stopping=leo_stopping_options(struct('enabled',true,'minPhaseSeconds',0, ...
    'patienceSeconds',1e-9,'minIterations',2,'relativeGap',0));
for name={'Tabu','SB','Local'}
    sol=leo_run_benchmark_method(model.problem,[],model.xExample,name{1},method);
    assert(sol.stage1.service.fairness==truth && all(sol.service.demandRatio>=truth));
    assert(any(strcmp({sol.stage1.status,sol.stage2.status},'stagnation')));
    for stage={sol.stage1,sol.stage2}
        if strcmp(stage{1}.status,'stagnation'), assert(~stage{1}.stopping.nearOptimalCertified); end
    end
end
method.stopping.enabled=false; method.originalSearchRounds=4;
sol=leo_run_benchmark_method(model.problem,[],model.xExample,'Tabu',method);
assert(sol.stage1.iterations==4 && sol.stage2.iterations==4);
for pair={{'SB','sb_v12_lexicographic'},{'Local','local_v12_lexicographic'},{'Tabu','original_tabu'}}
    p=pair{1}; [a,b]=leo_plot_style(p{1}); [c,d]=leo_plot_style(p{2}); assert(isequal(a,c) && strcmp(b,d));
end
fprintf('PASS: adaptive original-bound near-optimal stopping, cumulative plateau clock, phase-specific objective, disabled compatibility, four plain method aliases, independent integer oracle and heuristic stagnation without false certification.\n');
end
function model=fixture(loose,near)
if nargin<2, near=false; end
p=leo_v12_parameters(); p.system.K=2; p.system.maxStreams=1;
p.system.qosTargetBits=1; p.system.bandwidthHz=1; p.statistics.serviceModel='slot_union'; p.problem.referenceBits=[];
p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); r=leo_build_resources(p); b.available=true(2,2); b.index=repmat((1:2).',1,2);
rates=4*ones(2,2); x=logical(eye(2));
if loose, rates=[10,4;4,1.1]; x=logical(fliplr(eye(2))); end
if near, rates=[4,4.04;4.04,4]; end
d=struct('serviceModel','slot_union','signalW',2.^rates-1,'noiseW',ones(2,2),'beamPowerW',zeros(2,2,2));
problem=leo_form_problem(p,r,b,d);
if near, problem.precheck.witness=x; end
model=struct('problem',problem,'parameters',p,'xExample',x,'surrogate',[], ...
    'timings',struct('physicalProblemSeconds',0,'proxySeconds',0));
end
function [best,total]=oracle(problem)
best=-Inf; total=-Inf;
for code=0:15
    x=reshape(logical(bitget(code,1:4)),2,2);
    if any(problem.data.hard.A*double(x(:))>problem.data.hard.rhs), continue; end
    s=problem.evaluate(x);
    if s.fairness>best, best=s.fairness; total=s.totalBits;
    elseif s.fairness==best, total=max(total,s.totalBits); end
end
end
