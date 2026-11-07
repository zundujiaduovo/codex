function test_leo_method()
%TEST_LEO_METHOD 精确位串/组枚举验证能量、硬约束、有效界及两阶段原始服务验收。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
checks = 0;
options = leo_method_options(struct('verbose',false,'fairnessRounds',8,'throughputRounds',5, ...
    'sbSteps',80,'sbTrajectories',6,'refreshEvery',2,'recoveryEvaluations',60, ...
    'randomInitialSchedules',1,'maxSeconds',60));
problem = toy_problem(false); data = problem.data;
proxy = leo_build_service_surrogates(problem);
weights = [1;2;3;4]/sum(data.qosTargetBits);

% 1. 参数错误须明确拒绝，旧参数结构可补默认方法选项。
for bad = {struct('penaltyFactor',1),struct('sbSteps',0),struct('stepExponent',.4),struct('bogus',1)}
    failed = false; try, leo_method_options(bad{1}); catch, failed = true; end
    assert(failed);
end
p = leo_default_parameters(); p.statistics.serviceModel = 'slot_union'; p = rmfield(p,'method'); p = leo_validate_parameters(p);
assert(~p.method.enabled); checks = checks+1;

% 2. 枚举全部用户/松弛位，独立展开罚项；对称/上三角 QUBO 能量一致。
qubo = leo_build_resource_qubo(data,proxy.lower,1,weights,options);
assert(qubo.capacityIncluded && qubo.nBits==6);
bits = all_bits(qubo.nBits); energies = zeros(1,size(bits,2)); feasible = false(size(energies));
for k = 1:size(bits,2)
    z = bits(:,k); x = z(1:qubo.nUsers); slack = qubo.slackWeights.'*z(qubo.nUsers+1:end);
    reward = qubo.A.'*x;
    conflictPairs = 0;
    for i = 1:qubo.nUsers
        for j = i+1:qubo.nUsers
            reward = reward-qubo.B(i,j)*x(i)*x(j);
            conflictPairs = conflictPairs+(qubo.beamIndex(i)==qubo.beamIndex(j))*x(i)*x(j);
        end
    end
    explicit = -reward+qubo.capacityPenalty*(sum(x)+slack-data.maxStreams)^2+ ...
        qubo.beamPenalty*conflictPairs;
    energies(k) = qubo.constant+z.'*qubo.Qsym*z;
    assert(abs(energies(k)-explicit)<1e-11);
    assert(abs(energies(k)-(qubo.constant+z.'*qubo.Qupper*z))<1e-11);
    feasible(k) = sum(x)<=data.maxStreams && conflictPairs==0 && sum(x)+slack==data.maxStreams;
end
assert(all(feasible(energies<=min(energies)+1e-12))); checks = checks+1;

% 3. 全部位串的 Ising 绝对能量与 QUBO 相等，含常数与线性场。
ising = leo_qubo_to_ising(qubo);
spin = 2*bits-1;
isingEnergy = ising.constant+ising.h.'*spin+sum(spin.*(ising.J*spin),1)/2;
assert(max(abs(isingEnergy-energies))<1e-11 && all(diag(ising.J)==0));
checks = checks+1;

% 4. 所有合法组：加权下界等于 A/B 二次收益，松弛重编码后罚项严格为零。
groups = leo_enumerate_resource_groups(data,1,100);
for k = 1:size(groups,2)
    x = false(data.shape); x(:,1) = groups(:,k);
    lower = leo_evaluate_quadratic_service(data,proxy.lower,x);
    z = leo_encode_group_bits(qubo,groups(:,k));
    assert(abs(qubo.constant+z.'*qubo.Qsym*z+weights.'*lower.userBits)<1e-11);
end
checks = checks+1;

% 5. 容量冗余时，删松弛位与保留完整编码的最优能量一致。
redundant = data; redundant.maxStreams = 3;
reduced = leo_build_resource_qubo(redundant,proxy.lower,1,weights,options);
forcedOptions = options; forcedOptions.removeRedundantCapacity = false;
full = leo_build_resource_qubo(redundant,proxy.lower,1,weights,forcedOptions);
assert(~reduced.capacityIncluded && reduced.nBits==4 && full.nBits==6);
assert(abs(min_qubo(reduced)-min_qubo(full))<1e-11);
zero = leo_build_resource_qubo(data,proxy.lower,1,zeros(4,1),options);
scaled = leo_build_resource_qubo(data,proxy.lower,1,3*weights,options);
assert(zero.beamPenalty>0 && abs(scaled.beamPenalty/qubo.beamPenalty-3)<1e-12);
checks = checks+1;

% 6. 全部原始用户位串经修复均满足波束/容量；局部润色不降低二次收益。
users = all_bits(4);
for k = 1:size(users,2)
    repaired = leo_repair_group(qubo,users(:,k));
    before = qubo.A.'*double(repaired)-double(repaired).'*qubo.B*double(repaired)/2;
    polished = leo_polish_group(qubo,repaired,options.polishMoves);
    after = qubo.A.'*double(polished)-double(polished).'*qubo.B*double(polished)/2;
    z = leo_encode_group_bits(qubo,polished);
    assert(sum(polished)<=2 && numel(unique(qubo.beamIndex(polished)))==sum(polished));
    assert(after>=before-1e-12 && abs(qubo.constant+z.'*qubo.Qsym*z+after)<1e-11);
end
checks = checks+1;

% 7. 非零线性场的可分 Ising：力的符号、统一缩放、多轨迹结果可复现。
simple.J = zeros(4); simple.h = [2;-3;1;-1]; simple.constant = 7; simple.nBits = 4;
sbOptions = options; sbOptions.sbSteps = 200;
rng(7); sb = leo_ballistic_sb(simple,sbOptions,zeros(4,1));
rng(7); again = leo_ballistic_sb(simple,sbOptions,zeros(4,1));
assert(isequal(sb.bits,again.bits) && min(sb.energy)<1e-12 && ~sb.optimal);
assert(any(all(bsxfun(@eq,sb.bits,[0;1;0;1]),1))); checks = checks+1;

% 8. 近似资源解保留旧组，其固定价格收益不下降；合法性由原评价器复核。
inner = leo_solve_resource_sb(data,proxy.lower,1,weights,problem.precheck.witness(:,1),options);
x = false(data.shape); x(:,1) = inner.x; problem.evaluate(x);
assert(inner.score>=inner.oldScore-1e-12 && ~inner.optimal); checks = checks+1;

% 9. 价格更新方向、负下界保留和第二阶段权重；sAux 不是当前实际公平。
lambda = ones(4,1)/4;
[w,s] = leo_price_weights(data,lambda,'fairness'); assert(s==1 && isequal(w,lambda./data.qosTargetBits));
[~,s] = leo_price_weights(data,2*lambda,'fairness'); assert(s==0);
[w,s] = leo_price_weights(data,lambda,'throughput',.3);
assert(s==.3 && max(abs(w-lambda./data.qosTargetBits-1/data.referenceBits))<1e-15);
next = leo_update_prices(lambda,[-10;100;0;50],100*ones(4,1),.5,.2);
assert(max(abs(next-[.37;.15;.35;.25]))<1e-12); checks = checks+1;

% 10. UB1 对每个原始合法组有效，且不大于无干扰上界；候选含同波束用户。
cache = leo_prepare_upper_bounds(data);
for trial = 1:4
    lambda = (1:4).'/trial;
    bound = leo_original_upper_bound(data,cache,lambda,'throughput',0);
    [w,~] = leo_price_weights(data,lambda,'throughput',0);
    for m = 1:data.shape(2)
        g = leo_enumerate_resource_groups(data,m,100);
        raw = leo_resource_group_services(data,m,g);
        assert(max(w.'*raw)<=bound.resource(m)+1e-11);
        free = w.*cache.serviceByCardinality(:,m,1);
        freeBeams = [max(free(1:2));free(3:4)]; freeBeams = sort(freeBeams,'descend');
        assert(bound.resource(m)<=sum(freeBeams(1:2))+1e-11);
    end
end
checks = checks+1;

% 11. 独立完整位串枚举原问题，验证公平上界和固定门槛吞吐上界。
[allServices,allSchedules] = enumerate_original(problem);
fair = [allServices.fairness]; exactFair = max(fair);
floor = exactFair*.9;
feasibleFloor = cellfun(@(v) all(v>=floor),{allServices.demandRatio});
exactTotal = max([allServices(feasibleFloor).totalBits]);
for trial = 1:4
    lambda = (1:4).'/trial;
    ubF = leo_original_upper_bound(data,cache,lambda,'fairness');
    ubV = leo_original_upper_bound(data,cache,lambda,'throughput',floor);
    assert(ubF.value>=exactFair-1e-12 && ubV.value>=exactTotal/data.referenceBits-1e-12);
end
checks = checks+1;

% 12. 原始服务恢复严格单调、合法，动作数受限，关闭跨块时确实不执行交换。
recoveryOptions = options; recoveryOptions.crossResourceFraction = 0;
recovered = leo_recover_schedule(problem,false(data.shape),'fairness',0,recoveryOptions,1);
assert(recovered.evaluations<=options.recoveryEvaluations && recovered.crossEvaluations==0);
assert(recovered.service.totalBits>0 && recovered.acceptedMoves>0); problem.evaluate(recovered.x);
recoveryOptions.recoveryEvaluations = 0;
idle = leo_recover_schedule(problem,recovered.x,'fairness',0,recoveryOptions,1);
assert(isequal(idle.x,recovered.x) && idle.evaluations==0); checks = checks+1;

% 13. 两阶段完整路径，不能读取穷举；保存值单调，价格只由当轮下界反馈。
savedRng = rng;
method = leo_solve_schedule(problem,proxy,options);
assert(isequal(rng,savedRng) && ~method.usesExhaustiveSolution);
assert(method.service.fairness<=exactFair+1e-12 && method.fairnessUpperBound>=exactFair-1e-12);
assert(all(method.service.demandRatio>=method.fairnessFloor));
assert(method.stage2.service.totalBits>=method.stage1.service.totalBits);
assert(max(abs(method.stage2.proxyEpochTouchErrorsBits))<1e-10);
assert(all(diff(method.stage1.history.savedFairness)>=0));
assert(all(diff(method.stage2.history.savedTotalBits)>=0));
for phase = {method.stage1,method.stage2}
    h = phase{1}.history;
    for k = 1:phase{1}.rounds
        expected = max(0,h.lambda(:,k)+h.step(k)*(h.sAux(k)-h.lowerUserBits(:,k)./data.qosTargetBits));
        assert(max(abs(expected-h.lambdaNext(:,k)))<1e-14);
        problem.evaluate(h.priceX(:,:,k));
        assert(h.innerImprovement(k)>=-1e-12);
    end
end
checks = checks+1;

% 14. 第二阶段上界针对实际取得的门槛；不能直接拿原公平最优点的吞吐作基准。
feasibleFloor = cellfun(@(v) all(v>=method.fairnessFloor),{allServices.demandRatio});
exactTotal = max([allServices(feasibleFloor).totalBits]);
assert(method.service.totalBits<=exactTotal+1e-10);
assert(method.throughputUpperBoundBits>=exactTotal-1e-10);
checks = checks+1;

% 15. 预算不足仍返回可行完整日程；种子复现不依赖外部 rng 状态。
again = leo_solve_schedule(problem,proxy,options);
assert(isequal(again.x,method.x) && isequal(again.stage1.history.priceX,method.stage1.history.priceX));
short = options; short.maxSeconds = 1e-9;
timed = leo_solve_schedule(problem,proxy,short);
assert(timed.stage1.rounds==0 && timed.stage2.rounds==0 && timed.hardFeasible);
assert(all(timed.service.demandRatio>=timed.fairnessFloor)); checks = checks+1;

% 16. 空物理候选域：无用户位、零服务/零公平、有限输出。
empty = toy_problem(true); emptyProxy = leo_build_service_surrogates(empty);
dead = leo_solve_schedule(empty,emptyProxy,options);
emptyInner = leo_solve_resource_sb(empty.data,emptyProxy.lower,1,ones(4,1),false(4,1),options);
assert(dead.service.totalBits==0 && dead.fairnessUpperBound==0 && dead.throughputGapBits==0);
assert(~any(emptyInner.x) && emptyInner.nBits==0); checks = checks+1;

% 17. 已达到公平封顶时，第一阶段可直接认证；阶段 2 从相切点严格保留门槛。
best = find(fair==exactFair,1); capped = problem;
cd = data; cd.qosTargetBits = allServices(best).userBits/2;
capped.data = cd; capped.evaluate = @(x) leo_evaluate_service(cd,x);
cappedProxy = leo_build_service_surrogates(capped);
cappedResult = leo_solve_schedule(capped,cappedProxy,options,allSchedules{best});
assert(cappedResult.stage1.service.fairness==1 && cappedResult.stage1.certifiedWithinTolerance);
assert(cappedResult.stage1.rounds==0 && all(cappedResult.service.demandRatio>=1));
checks = checks+1;
fprintf('PASS: %d Lagrangian/SB method test groups.\n',checks);
end

function bits = all_bits(n)
bits = zeros(n,2^n);
for k = 0:2^n-1, bits(:,k+1) = bitget(k,1:n).'; end
end

function value = min_qubo(q)
z = all_bits(q.nBits);
value = min(q.constant+sum(z.*(q.Qsym*z),1));
end

function [services,schedules] = enumerate_original(problem)
data = problem.data; bits = all_bits(prod(data.shape)); schedules = {}; services = struct([]);
for k = 1:size(bits,2)
    z = bits(:,k);
    if any(z>data.hard.upper) || any(data.hard.A*z>data.hard.rhs), continue; end
    x = reshape(logical(z),data.shape);
    schedules{end+1} = x; %#ok<AGROW>
    services(end+1) = problem.evaluate(x); %#ok<AGROW>
end
end

function problem = toy_problem(empty)
p = leo_default_parameters(); p.statistics.serviceModel = 'slot_union'; p.system.K = 4; p.system.maxStreams = 2;
p.system.bandwidthHz = 10; p.system.qosTargetBits = 100;
p.time.nSlots = 4; p.time.blockSlots = 2; p.time.slotDurationS = .5;
p.time.baseOverheadS = 0; p.time.configOverheadS = 0;
p = leo_validate_parameters(p); r = leo_build_resources(p);
b.available = repmat(~empty,4,2); b.index = repmat([1;1;2;3],1,2);
if empty, b.index(:) = 0; end
d.signalW = [1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW = repmat([1,2,1.5,3],4,1); d.beamPowerW = zeros(4,3,4);
for t = 1:4
    C = [2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t);
    d.beamPowerW(:,:,t) = C;
end
problem = leo_form_problem(p,r,b,d);
end
