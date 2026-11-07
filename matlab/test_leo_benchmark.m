function test_leo_benchmark()
%TEST_LEO_BENCHMARK 对比可信性：原始增量服务、零切点、MILP 等价性、预算和共同初始化。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
% 无输入；全部断言通过时报告检查组数。小模型的精确参考来自独立位串枚举。
checks = 0; skipped = 0; problem = fixture(); data = problem.data;
proxy = leo_build_service_surrogates(problem); zero = leo_build_service_surrogates(problem,'zero');
schedules = {}; scores = []; lowerScores = [];
for code = 0:2^prod(data.shape)-1
    x = reshape(logical(bitget(code,1:prod(data.shape))),data.shape);
    if any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
    schedules{end+1} = x; %#ok<AGROW>
    raw = problem.evaluate(x); low = leo_evaluate_quadratic_service(data,proxy.lower,x);
    zlow = leo_evaluate_quadratic_service(data,zero.lower,x);
    assert(all(zlow.userBits<=raw.userBits+1e-10));
    for m = 1:data.shape(2)
        fast = leo_resource_service(data,m,x(:,m));
        assert(max(abs(fast-raw.resourceBits(:,m)))<1e-10);
    end
    scores(end+1) = raw.fairness; lowerScores(end+1) = max(0,low.fairness); %#ok<AGROW>
end
assert(all(zero.referenceW(:)==0)); checks = checks+1;

% McCormick 线性服务对每个合法二元日程精确等于原二次代理。
milp = leo_form_proxy_milp(data,proxy.lower,'fairness');
for k = 1:numel(schedules)
    x = schedules{k}; z = zeros(numel(milp.f),1); z(1:numel(x)) = x(:);
    for j = 1:size(milp.pairs,1)
        pair = milp.pairs(j,:); z(numel(x)+j) = x(pair(1),pair(3))*x(pair(2),pair(3));
    end
    low = leo_evaluate_quadratic_service(data,proxy.lower,x);
    assert(max(abs(milp.serviceMatrixBits*z-low.userBits))<1e-10);
    z(end) = max(0,low.fairness);
    if all(low.userBits>=0), assert(all(milp.A*z<=milp.b+1e-12)); end
end
empty = data; empty.available(:) = false; empty.beamIndex(:) = 0; empty.hard.upper(:) = 0;
emptyLower = proxy.lower; emptyLower.aBits(:) = 0; emptyLower.bBits(:) = 0;
emptyModel = leo_form_proxy_milp(empty,emptyLower,'fairness');
assert(isempty(emptyModel.pairs) && nnz(emptyModel.serviceMatrixBits)==0);
checks = checks+1;

% 实际整数求解与独立完整枚举的代理公平最优值一致。
hasMilp = exist('glpk','file')~=0 || exist('intlinprog','file')~=0;
if hasMilp
    solved = leo_call_milp(milp,10);
    assert(solved.optimal && abs(-solved.objective-max(lowerScores))<1e-7);
    checks = checks+1;
else
    fprintf('SKIP: MILP solver test (no intlinprog/GLPK).\n');
    skipped = skipped+1;
end

% 邻域先验证硬约束，原始累计量必须与独立完整评价一致。
x = problem.precheck.witness; service = problem.evaluate(x);
pool = leo_original_neighbors(problem,x,service,100,1,[]);
assert(~isempty(pool));
for k = 1:numel(pool)
    exact = problem.evaluate(pool(k).x);
    assert(max(abs(exact.userBits-pool(k).service.userBits))<1e-10);
    assert(isequal(pool(k).changed,find(pool(k).x~=x)));
end
checks = checks+1;

% 对比试验：相同 seed 的各方法使用完全相同初始化，原式验收及随机状态恢复。
o = leo_method_options(struct('fairnessRounds',2,'throughputRounds',2, ...
    'sbSteps',30,'sbTrajectories',3,'randomInitialSchedules',1,'localRestarts',3, ...
    'recoveryEvaluations',20,'recoveryPasses',2,'verbose',false));
model.problem = problem; model.parameters = struct('seed',1); model.xExample = x; model.surrogate = proxy;
model.timings.physicalProblemSeconds = .001; model.timings.proxySeconds = .001;
methods = {'initial','original_greedy','original_exchange','original_tabu','price_sb','price_local', ...
    'sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
if hasMilp, methods{end+1} = 'proxy_milp'; end
opts = leo_benchmark_options(struct('methods',{methods},'seeds',17,'budgetSeconds',1, ...
    'makePlots',false,'verbose',false,'method',o));
before = rng; report = leo_benchmark_case(model,opts); assert(isequal(rng,before));
assert(all(strcmp({report.records.status},'completed')));
for k = 1:numel(report.solutions)
    result = report.solutions{k}; row = report.records(k);
    assert(isequal(result.initial.x,report.solutions{1}.initial.x));
    assert(row.hardFeasible && result.service.fairness<=max(scores)+1e-10);
    assert(all(result.service.demandRatio>=result.fairnessFloor));
    assert(result.stage2.service.totalBits>=result.stage1.service.totalBits);
    assert(row.fairnessUpperBound>=max(scores)-1e-10 && row.exactFairnessGap>=0);
    assert(row.endToEndSeconds>=row.searchSeconds && ~result.usesExhaustiveSolution);
end
checks = checks+1;

% 缺失求解器、预处理用完预算不得生成伪造的零分或成功记录。
opts.methods = {'price_miqp'};
if exist('gurobi','file')==0
    unavailable = leo_benchmark_case(model,opts);
    assert(strcmp(unavailable.records.status,'unavailable') && isnan(unavailable.records.fairness));
    assert(unavailable.summary.completed==0 && unavailable.summary.unavailable==1);
end
opts.methods = {'price_sb'}; opts.budgetSeconds = .0001; opts.exhaustive = false;
limited = leo_benchmark_case(model,opts);
assert(strcmp(limited.records.status,'budget_exhausted_before_search') && isnan(limited.records.totalBits));
checks = checks+1;

% 固定公平门槛下的吞吐证书：直接用原始枚举验证 MILP 对照报告的独立上界。
if hasMilp
    index = find(strcmp({report.records.method},'proxy_milp'));
    method = report.solutions{index}; feasibleValues = [];
    for k = 1:numel(schedules)
        raw = problem.evaluate(schedules{k});
        if all(raw.demandRatio>=method.fairnessFloor), feasibleValues(end+1) = raw.totalBits; end %#ok<AGROW>
    end
    assert(method.throughputUpperBoundBits>=max(feasibleValues)-1e-10);
    checks = checks+1;
else
    skipped = skipped+1;
end
fprintf('PASS: %d benchmark test groups; SKIP: %d (MILP backend present: %d).\n',checks,skipped,hasMilp);
end

function problem = fixture()
p = leo_default_parameters(); p.statistics.serviceModel = 'slot_union'; p.system.K = 4; p.system.maxStreams = 2;
p.system.bandwidthHz = 10; p.system.qosTargetBits = 100;
p.time.nSlots = 4; p.time.blockSlots = 2; p.time.slotDurationS = .5;
p.time.baseOverheadS = 0; p.time.configOverheadS = 0;
p = leo_validate_parameters(p); r = leo_build_resources(p);
b.available = true(4,2); b.index = repmat([1;1;2;3],1,2);
d.signalW = [1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW = repmat([1,2,1.5,3],4,1); d.beamPowerW = zeros(4,3,4);
for t = 1:4, d.beamPowerW(:,:,t) = [2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem = leo_form_problem(p,r,b,d);
end
