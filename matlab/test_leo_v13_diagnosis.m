function test_leo_v13_diagnosis()
%TEST_LEO_V13_DIAGNOSIS 独立原式枚举/已知LP最优与可手算的三类动作见证。
model=fixture(3,2,1,2*ones(3,2),0); report=as_report(model);
bound=leo_cardinality_fairness_bound(report,struct('maxSeconds',10));
truth=enumerate(model.problem);
assert(truth==0 && abs(bound.upper-4/3)<1e-6 && bound.lpConverged);
assert(bound.upper>truth,'LP松弛最优不能冒充整数原问题最优。');
model=fixture(3,2,2,[4,6;5,3;3,7],.3);
model.problem.data.design.serviceScale=[.8;.9;.85]; model.problem.data.design.serviceMarginBits=[.2;.3;.1];
model.problem.data=rmfield(model.problem.data,'fairnessUpperLimit');
model.problem.evaluate=@(x) leo_evaluate_service(model.problem.data,x);
report=as_report(model); truth=enumerate(model.problem);
for seconds=[0,10]
    b=leo_cardinality_fairness_bound(report,struct('maxSeconds',seconds));
    assert(b.upper>=truth-1e-8 && b.upper<=b.coarseUpper+1e-7);
end
partial=leo_cardinality_fairness_bound(report,struct('maxSeconds',10,'maxIterations',1));
assert(partial.upper>=truth-1e-8);
% 真正执行的求解器记录在线切点、价格、内层提案及原式Tabu改进。
method=leo_method_options(struct('maxSeconds',5,'fairnessRounds',3,'throughputRounds',3, ...
    'originalSearchRounds',6,'sbSteps',10,'sbTrajectories',2,'localRestarts',2,'polishMoves',2, ...
    'randomInitialSchedules',0,'recoveryEvaluations',8,'verbose',false,'audit',struct('enabled',true)));
before=rng;
for name={'Tabu','SB','Local'}
    sol=leo_run_benchmark_method(model.problem,[],false(model.problem.data.shape),name{1},method);
    if strcmp(name{1},'Tabu'), assert(isfield(sol.stage1,'auditMoves'));
    else
        assert(isfield(sol.stage1,'auditSnapshots') && ~isempty(sol.stage1.auditSnapshots));
        a=sol.stage1.auditSnapshots{1}; assert(isfield(a,'proposed') && numel(a.lambda)==3);
    end
    assert(all(sol.service.demandRatio>=sol.fairnessFloor));
end
assert(isequal(rng,before));
% 向量内层在无时间截断时与冻结版本返回相同组、分数及随机流。
proxy=leo_v12_build_service_surrogates(model.problem,'current_schedule',false(model.problem.data.shape));
legacy=leo_v8_method_options(struct('sbSteps',20,'sbTrajectories',3,'localRestarts',3,'polishMoves',12,'verbose',false));
for solver={'sb','local'}
    legacy.innerSolver=solver{1}; rng(193,'twister');
    old=leo_v8_solve_resource(model.problem.data,proxy.lower,1,ones(3,1),false(3,1),legacy,struct('timer',tic,'seconds',30)); oldRng=rng;
    rng(193,'twister'); fast=leo_v13_solve_resource(model.problem.data,proxy.lower,1,ones(3,1),false(3,1),legacy,struct('timer',tic,'seconds',30));
    assert(isequal(old.x,fast.x) && old.score==fast.score && isequal(rng,oldRng));
end
rng(before);
directory=tempname; mkdir(directory); cleanup=onCleanup(@() rmdir(directory,'s')); %#ok<NASGU>
many=fixture(3,1,1,[1;2;3],0); multiple=probe_report(many,logical([1;0;0]),zeros(3,1));
checked=run_leo_v13_candidate_audit(multiple,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'multiple')),false);
assert(numel(checked.rows)==2,'多个候选必须复用同一原始参考服务，不能被加权标量覆盖。');
% 一块L=1：1bit用户换成2bit用户，原加权增益可手算为-9.5或+0.5。
model=fixture(2,1,1,[1;2],0); x=logical([1;0]);
report=probe_report(model,x,[10;0]);
audit=run_leo_v13_candidate_audit(report,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'weight')),false);
assert(~isempty(audit.rows) && any([audit.rows.weightMisaligned]));
assert(any(abs([audit.rows.originalWeightedGain]+9.5)<1e-10));
report=probe_report(model,x,[0;0]);
audit=run_leo_v13_candidate_audit(report,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'inner')),false);
assert(any([audit.rows.innerMiss]==1) && any(abs([audit.rows.proxyWeightedGain]-.5)<1e-10));
% 同一真实候选：总服务增加，但I=0处的切线严重低估双用户组，出现代理排序翻转。
model=fixture(2,1,2,[log2(11);log2(11)],2); report=probe_report(model,x,[0;0]);
audit=run_leo_v13_candidate_audit(report,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'proxy')),false);
assert(any([audit.rows.proxyReversed]));
at=find([audit.rows.proxyReversed],1); row=audit.rows(at);
assert(row.originalWeightedGain>0 && row.proxyWeightedGain<0 && row.innerMiss==0);
% 旧结果无法验证内层是否漏掉动作，必须留为NaN；不伪造在线证据。
model=fixture(2,1,1,[1;2],0); report=probe_report(model,x,[0;0]);
snap=report.solutions{1}.stage2.auditSnapshots{1};
report.solutions{1}.stage2=struct('x',x,'proxy',struct('referenceW',snap.referenceW), ...
    'history',struct('lambda',snap.lambda));
audit=run_leo_v13_candidate_audit(report,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'legacy')),false);
assert(all(isnan([audit.rows.innerMiss])));
% 已记录的Tabu动作也走同样的原式/代理评分路径。
report=probe_report(model,x,[0;0]); report.records(2)=struct('method','Tabu','seed',7,'status','completed');
move=struct('xBefore',x,'xAfter',logical([0;1]),'phase','throughput','floor',0);
report.solutions{2}=struct('stage1',struct('auditMoves',{{}}), ...
    'stage2',struct('auditMoves',{{move}}));
audit=run_leo_v13_candidate_audit(report,struct('maxSeconds',10,'outputDirectory',fullfile(directory,'tabu')),false);
assert(any(strcmp({audit.rows.origin},'recorded_Tabu_move')) && isequal(rng,before));
fprintf('PASS: cardinality LP dual bound vs independent integer oracle and known fractional optimum; risk margins, partial solves, actual online snapshots, hand-calculated price/proxy/inner witnesses, real Tabu move replay and legacy unknowns.\n');
end
function model=fixture(K,M,L,rates,interference)
p=leo_v12_parameters(); p.system.K=K; p.system.maxStreams=L; p.system.bandwidthHz=1; p.system.qosTargetBits=1;
p.problem.referenceBits=[]; p.statistics.serviceModel='slot_union'; p.time.nSlots=M; p.time.blockSlots=1;
p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); r=leo_build_resources(p); b.available=true(K,M); b.index=repmat((1:K).',1,M);
d=struct('serviceModel','slot_union','signalW',2.^rates-1,'noiseW',ones(K,M),'beamPowerW',interference*ones(K,K,M));
problem=leo_form_problem(p,r,b,d); model=struct('problem',problem,'parameters',p);
end
function report=as_report(model)
x=false(model.problem.data.shape); s=model.problem.evaluate(x);
report=struct('problemData',model.problem.data,'records',struct('method','Tabu','seed',7,'status','completed'), ...
    'solutions',{{struct('x',x,'stage1',struct('x',x,'service',s))}});
end
function report=probe_report(model,x,lambda)
report=as_report(model); report.records.method='SB';
snapshot=struct('iteration',1,'phase','throughput','floor',0,'x',x,'lambda',lambda, ...
    'referenceW',zeros(size(model.problem.data.design.signalW)),'proposed',x,'solved',true(1,model.problem.data.shape(2)));
report.solutions{1}=struct('stage1',struct('auditSnapshots',{{}},'history',struct('lambda',[])), ...
    'stage2',struct('auditSnapshots',{{snapshot}},'history',struct('lambda',lambda)),'fairnessFloor',0);
end
function best=enumerate(problem)
best=0; n=prod(problem.data.shape);
for code=0:2^n-1
    x=reshape(logical(bitget(code,1:n)),problem.data.shape);
    if any(problem.data.hard.A*double(x(:))>problem.data.hard.rhs), continue; end
    s=problem.evaluate(x); best=max(best,s.fairness);
end
end
