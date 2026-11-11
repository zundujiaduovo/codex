function test_leo_problem()
%TEST_LEO_PROBLEM 原始问题形成检查；独立 CDF 数值、直接接收功率、枚举硬约束。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
legacy = leo_default_parameters(); legacy.statistics.serviceModel = 'slot_union';
model = run_leo_sinr(legacy);
p = model.parameters; problem = model.problem;
checks = 0;

% 1. 用户指定的 32/8 比例和 50 ms 固定资源，平均功率预算一致。
assert(model.codebook.nBeams==32 && p.system.maxStreams==8 && p.system.nRF==8);
assert(p.time.blockSlots==5 && model.resources.nResources==20);
assert(p.system.maxStreams*p.system.streamPowerW==p.system.maxPowerW);
assert(model.codebook.candidateCount>=32 && numel(unique(model.codebook.selectedCandidateIndex))==32);
assert(all(abs(model.resources.dataDurationS(1:5)-[.0088,.009,.009,.009,.009])<1e-14));
checks = checks+1;

% 2. 独立基准由 scipy.stats.ncx2.ppf(eps,2,2*k)/(2*(1+k)) 生成。
table = [0,.01,.010050335853501437;1,.01,.013592238646510466; ...
    10,.05/3200,.015963795062721838;10,.001,.11168146703185394; ...
    10,.5,.9549263484071695;10,.95,1.7540312227238666;100,.001,.60904644859296031];
for row = 1:size(table,1)
    z = leo_rician_power_quantile(table(row,2),table(row,1));
    assert(abs(z-table(row,3))<5e-9);
    assert(z<=table(row,3)+1e-13);
    [~,upper] = leo_rician_power_cdf(z,table(row,1));
    assert(upper<=table(row,2)+1e-14);
end
checks = checks+1;

% 3. 不是选完日程才分配风险，也不是按 M 个资源数计风险事件。
d = model.design;
expectedEvents=nnz(model.beams.available(:,model.resources.slotToResource));
assert(d.nEvents==nnz(d.eventMask) && d.nEvents==expectedEvents);
assert(d.nEvents>nnz(model.beams.available));
assert(abs(d.usedRisk-p.statistics.totalRisk)<1e-13);
assert(all(d.risk(~d.eventMask)==0) && all(d.zeta(~d.eventMask)==0));
assert(all(d.zeta(d.eventMask)>0)); checks = checks+1;

% 4. 独立从 sqrt(Na*beta*zeta)*a 和 W 构造接收功率，核对服务和单位。
x = problem.precheck.witness;
service = problem.evaluate(x);
oracleSlot = zeros(p.system.K,p.time.nSlots);
for m = 1:model.resources.nResources
    users = find(x(:,m));
    W = sqrt(p.system.streamPowerW)*model.codebook.F(:,model.beams.index(users,m));
    for t = model.resources.slots{m}
        scale = sqrt(p.array.nElements*model.channel.beta(users,t).*d.zeta(users,t));
        h = bsxfun(@times,model.beams.response(:,users,t),scale.');
        powers = abs(h'*W).^2;
        for j = 1:numel(users)
            gamma = powers(j,j)/(d.noiseW(users(j),t)+sum(powers(j,[1:j-1,j+1:numel(users)])));
            oracleSlot(users(j),t) = model.resources.dataDurationS(t)*p.system.bandwidthHz*log1p(gamma)/log(2);
        end
    end
end
assert(max(abs(oracleSlot(:)-service.slotBits(:)))<1e-8);
assert(max(abs(sum(oracleSlot,2)-service.userBits))<1e-8);
assert(abs(sum(service.resourceBits(:))-service.totalBits)<1e-8);
checks = checks+1;

% 5. 回调有正确的负号、列优先索引、连续 s/整数 x、已知可行初始点。
PF = problem.stage1;
n = numel(x);
assert(numel(PF.lb)==n+1 && isequal(PF.intcon,(1:n).'));
assert(~any(PF.intcon==PF.sIndex) && PF.sIndex==n+1);
z = [double(x(:));service.fairness];
assert(PF.objective(z)==-service.fairness);
report = leo_check_problem_point(PF,z,1e-9); assert(report.feasible);
report = leo_check_problem_point(PF,PF.x0,1e-9); assert(report.feasible);
[c,eq] = PF.nonlcon(z);
assert(isempty(eq) && max(abs(c-(service.fairness-service.demandRatio)))<1e-12);
z(end) = min(1,service.fairness+.01);
report = leo_check_problem_point(PF,z,1e-9); assert(~report.feasible);
checks = checks+1;

% 6. 第二阶段门槛来自已给定的可行日程；全删掉服务时必须违反该门槛。
PV = problem.makeStage2(x);
assert(PV.s0==service.fairness && PV.s0>0 && ~PV.solved && ~PF.solved);
assert(abs(PV.objective(x(:))+service.totalBits/p.problem.referenceBits)<1e-12);
report = leo_check_problem_point(PV,PV.x0,1e-9); assert(report.feasible);
report = leo_check_problem_point(PV,zeros(n,1),1e-9); assert(~report.feasible);
checks = checks+1;

% 7. 优化回调可计算盒内连续延拓，但正整数条件另行检查，不偷用连续解。
fractional = [0.5*double(x(:));0];
[c,~] = PF.nonlcon(fractional); assert(all(isfinite(c)));
report = leo_check_problem_point(PF,fractional,1e-9);
assert(~report.feasible && report.integerViolation==0.5); checks = checks+1;

% 8. K=3,M=2 小例，枚举所有 64 组；稀疏矩阵必须等价于逐组硬约束。
toy = make_toy_data();
for code = 0:63
    bits = logical(bitget(code,1:6).');
    xx = reshape(bits,3,2);
    direct = all(sum(xx,1)<=2) && ~any(xx(1,:)&xx(2,:));
    viaMatrix = all(toy.hard.A*double(bits)<=toy.hard.rhs);
    assert(direct==viaMatrix);
end
check = leo_precheck_positive_fairness(toy);
assert(check.maxFlow==3 && check.canHavePositiveFairness);
assert(check.witnessService.fairness>0); checks = checks+1;

% 9. K<=LM 仍可能同码字冲突导致零公平；所有用户都有机会也不充分。
conflict = toy; conflict.beamIndex(:) = 1;
q = leo_default_parameters(); q.statistics.serviceModel = 'slot_union';q.system.K=3;q.system.maxStreams=2;
rr.nResources = 2; bb.available = true(3,2);bb.index=ones(3,2);
conflict.hard = leo_build_hard_constraints(q,rr,bb);
check = leo_precheck_positive_fairness(conflict);
assert(check.simpleCapacityNecessary && isempty(check.neverServiceableUsers));
assert(check.maxFlow==2 && check.forcedZeroFairness); checks = checks+1;

% 10. max-flow 与小例所有硬约束可行日程的最大“获服务用户数”一致。
best = 0;
for code = 0:63
    bits = logical(bitget(code,1:6).');
    if any(conflict.hard.A*double(bits)>conflict.hard.rhs), continue; end
    best = max(best,nnz(any(reshape(bits,3,2),2)));
end
assert(best==check.maxFlow); checks = checks+1;

% 11. 需求不是硬上限；目标比封顶公平可以等于 1，但吞吐不截断。
smallDemand = toy; smallDemand.qosTargetBits = ones(3,1)*1e-6;
rr = leo_evaluate_service(smallDemand,[1,0;0,1;1,1]);
assert(rr.fairness==1 && all(rr.userBits>smallDemand.qosTargetBits));
assert(rr.totalBits>sum(smallDemand.qosTargetBits)); checks = checks+1;

% 12. 同一统计/几何输入重建问题一致，瞬时 fading 不进入设计输入接口。
fresh = leo_prepare_design_service(p,model.resources,model.beams,model.channel,model.link);
assert(isequal(fresh,model.design));
changed = p; changed.system.K = p.system.K+3; changed.seed = 7;
cb = leo_build_codebook(changed);
assert(isequal(cb.F,model.codebook.F)); % 码本不随用户数或随机用户变化
assert(problem.precheck.canHavePositiveFairness && problem.precheck.maxFlow==p.system.K);
checks = checks+1;
fprintf('PASS: %d problem-formation test groups.\n',checks);
end

function data = make_toy_data()
% 两资源/每资源两槽，用非恒定系数避免均值信道替代逐槽速率而漏测。
p = leo_default_parameters(); p.statistics.serviceModel = 'slot_union'; p.system.K=3;p.system.maxStreams=2;
r.nResources = 2;
b.available = true(3,2); b.index = [1,1;1,1;2,2];
data.shape = [3,2];data.hard = leo_build_hard_constraints(p,r,b);
data.available = b.available;data.beamIndex = b.index;data.maxStreams=2;
data.slotToResource = [1,1,2,2];data.dataDurationS=[.02,.03,.01,.04];
data.bandwidthHz=100;data.qosTargetBits=[1;2;3];data.referenceBits=6;
data.design.signalW=[2,1,3,1;1,4,2,1;2,3,1,4];
data.design.noiseW=ones(3,4);
data.design.beamPowerW=zeros(3,2,4);
for t=1:4
    data.design.beamPowerW(:,:,t)=[data.design.signalW(1,t),.2*t; ...
        data.design.signalW(2,t),.1*t;.3*t,data.design.signalW(3,t)];
end
end
