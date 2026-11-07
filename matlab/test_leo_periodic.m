function test_leo_periodic()
%TEST_LEO_PERIODIC 概率证书、完整日程穷举、代理/增量/上界及边界条件。
reference = run_leo_sinr();
assert(reference.problem.precheck.maxFlow==32 && all(any(reference.beams.available,2)));
savedRng = rng;
rng(1,'twister'); usersA = leo_generate_users(reference.parameters);
rng(2,'twister'); usersB = leo_generate_users(reference.parameters);
rng(savedRng);
assert(isequal(usersA.latDeg,usersB.latDeg) && isequal(usersA.lonDeg,usersB.lonDeg));
p = leo_default_parameters(); p.system.K = 3; p.time.nSlots = 8;
p.time.blockSlots = 4; p.system.maxStreams = 2; p.system.bandwidthHz = 100;
p.system.qosTargetBits = [.3;.4;.5]; p = leo_validate_parameters(p);
r = leo_build_resources(p); b.available = true(3,2); b.index = repmat((1:3).',1,2);
c.noiseW = ones(3,8); link.signalW = repmat([8;6;10],1,8);
link.beamPowerW = repmat([8,.2,.4;.3,6,.1;.2,.3,10],1,1,8);
d = leo_prepare_design_service(p,r,b,c,link);
problem = leo_form_problem(p,r,b,d); data = problem.data;
assert(strcmp(d.serviceModel,'periodic_chernoff'));
assert(abs(d.badFadeProbabilityUpper-.011262715965)<1e-10);
assert(all(d.serviceScale>0 & d.serviceScale<1) && all(d.serviceMarginBits>0));
assert(abs(sum(d.userRisk)-p.statistics.totalRisk)<1e-14);
% 固定倾斜参数下，凹 log-MGF 的弦必须处处在下方。
for i = 1:3
    v = linspace(0,d.maxSlotBits(i),301);
    h = -log1p((1-d.badFadeProbabilityUpper)*expm1(-d.thetaPerBit(i)*v))/d.thetaPerBit(i);
    assert(all(d.serviceScale(i)*v<=h+1e-12));
end
proxy = leo_build_service_surrogates(problem); cache = leo_prepare_upper_bounds(data);
allServices = {}; allX = {};
for code = 0:63
    x = reshape(logical(bitget(code,1:6)),3,2);
    if any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
    s = problem.evaluate(x); allServices{end+1} = s; allX{end+1} = x; %#ok<AGROW>
    assert(max(abs(s.userBits-max(0,sum(s.resourceBits,2)-d.serviceMarginBits)))<1e-12);
    for m = 1:2
        fast = leo_resource_service(data,m,x(:,m));
        batch = leo_resource_group_services(data,m,x(:,m));
        assert(max(abs(fast-s.resourceBits(:,m)))<1e-12 && max(abs(fast-batch))<1e-12);
    end
    bounds = leo_evaluate_service_bounds(problem,proxy,x);
    assert(all(max(0,bounds.lower.userBits)<=s.userBits+1e-12));
    assert(all(s.userBits<=max(0,bounds.upper.userBits)+1e-12));
    touch = leo_build_service_surrogates(problem,'current_schedule',x);
    assert(touch.referenceTouchMaxAbsBits<1e-12);
    cert = leo_certify_period_qos(data,x,s.userBits);
    assert(cert.jointFailureUpper<=p.statistics.totalRisk+1e-12);
    % 独立穷举 2^8 种好/坏槽，直接验证证书，不用被测 Chernoff 公式当 oracle。
    good = zeros(256,8);
    for t = 1:8, good(:,t) = bitget((0:255).',t); end
    probBad = d.badFadeProbabilityUpper;
    probability = (1-probBad).^sum(good,2).*probBad.^(8-sum(good,2));
    for i = 1:3
        slot = s.slotBits(i,:)/d.serviceScale(i);
        failure = sum(probability(good*slot.'<s.userBits(i)-1e-12));
        assert(failure<=d.userRisk(i)+1e-12);
    end
end
% 所有价格和正/零公平门槛下，上界必须覆盖独立全枚举最优值。
fair = cellfun(@(s) s.fairness,allServices);
total = cellfun(@(s) s.totalBits,allServices);
prices = [zeros(3,1),ones(3,1)/3,[.1;.7;2]];
for j = 1:size(prices,2)
    ub = leo_original_upper_bound(data,cache,prices(:,j),'fairness');
    assert(ub.value>=max(fair)-1e-12);
    for floorValue = [0,max(fair)/2,max(fair)]
        ub = leo_original_upper_bound(data,cache,prices(:,j),'throughput',floorValue);
        assert(ub.value*data.referenceBits>=max(total(fair>=floorValue))-1e-12);
    end
end
ex = leo_exhaustive_search(problem,struct('verbose',false));
assert(ex.optimal && abs(ex.fairness-max(fair))<1e-12);
assert(abs(ex.totalBits-max(total(fair==max(fair))))<1e-12);
pool = leo_original_neighbors(problem,ex.x,ex.service,80,1,[]);
for j = 1:numel(pool)
    exact = problem.evaluate(pool(j).x);
    assert(max(abs(exact.userBits-pool(j).service.userBits))<1e-12);
end
% MILP 的服务矩阵是 A_lower，QoS 右端必须含一次 margin。
model = leo_form_proxy_milp(data,proxy.lower,'fairness');
assert(max(abs(model.b(end-2:end)+d.serviceMarginBits./data.qosTargetBits))<1e-12);
if exist('glpk','file')~=0 || exist('intlinprog','file')~=0
    touch = leo_build_service_surrogates(problem,'current_schedule',ex.x);
    modelV = leo_form_proxy_milp(data,touch.lower,'throughput',ex.fairness);
    expected = -Inf;
    for j = 1:numel(allX)
        low = leo_evaluate_quadratic_service(data,touch.lower,allX{j});
        if all(low.demandRatio>=ex.fairness-1e-12), expected = max(expected,low.normalizedThroughput); end
    end
    solved = leo_call_milp(modelV,10);
    assert(solved.optimal && abs(solved.objective+expected)<1e-8);
end
% 空日程仍合法、保证为零；完全不可见时有限且为零。
empty = problem.evaluate(false(3,2));
assert(empty.fairness==0 && empty.totalBits==0 && all(empty.signedUserBits<0));
b.available(:) = false;
dead = leo_prepare_design_service(p,r,b,c,link);
assert(all(dead.serviceMarginBits==0) && all(dead.serviceScale==0));
% 不能在相关衰落设置下宣称独立槽证书。
bad = p; bad.statistics.independentSlots = false; rejected = false;
try, leo_validate_parameters(bad); catch, rejected = true; end
assert(rejected);
% 历史参数缺少模式字段时仍保持旧语义。
old = p; old.statistics = struct('totalRisk',.05); old = leo_validate_parameters(old);
assert(strcmp(old.statistics.serviceModel,'slot_union'));
% 独立验证器在近乎无衰落极限应还原原始 Z=1 服务，并恢复调用方 RNG。
before = rng;
mc = leo_sample_period_service(data,ex.x,1e12,200,123);
after = rng; nominal = leo_evaluate_nominal_service(data,ex.x);
assert(isequal(before,after));
assert(abs(mc.meanTotalBits-nominal.totalBits)<1e-5*nominal.totalBits);
assert(mc.jointFailure95Upper>=1-mc.jointSuccessRate);
fprintf('PASS: periodic certificate, all 49 schedules, exact Bernoulli tails, incremental/proxy/exhaustive/upper-bound checks.\n');
end
