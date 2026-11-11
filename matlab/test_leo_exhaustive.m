function test_leo_exhaustive()
%TEST_LEO_EXHAUSTIVE 以独立全二元位枚举核对穷举算法，不使用同一组生成器。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
o = leo_exhaustive_options(); o.verbose=false;
checks = 0;

% 1. 跨资源的全局选择：逐块最大吞吐会错过公平最优日程。
problem = toy_problem([100,99;98,1],[1000;1000],1,[1,1;2,2],true(2,2));
r = leo_exhaustive_search(problem,o);
assert(r.completed && r.optimal && r.visitedSchedules==9);
assert(isequal(r.x,logical([0,1;1,0])) && abs(r.fairness-.098)<1e-12);
assert(abs(r.totalBits-197)<1e-10);
checks=checks+1;

% 2. 同波束多人只许选一人，空组保留；和 2^(K*M) 独立枚举比较。
problem = toy_problem([30,10;10,40;20,20],[20;30;25],2,[1,1;1,1;2,2],true(3,2));
r = leo_exhaustive_search(problem,o);
oracle = binary_oracle(problem);
assert(all(r.estimate.groupsPerResource==6) && r.visitedSchedules==36);
assert(abs(r.fairness-oracle.fairness)<1e-12 && abs(r.totalBits-oracle.totalBits)<1e-10);
for m=1:2
    groups=leo_enumerate_resource_groups(problem.data,m,100);
    assert(size(groups,2)==6 && ~any(groups(:,1)));
    assert(size(unique(groups.','rows'),1)==6);
    cache=leo_resource_group_services(problem.data,m,groups);
    for g=1:size(groups,2)
        x=false(3,2);x(:,m)=groups(:,g);
        service=problem.evaluate(x);
        assert(max(abs(cache(:,g)-service.userBits))<1e-10);
    end
end
checks=checks+1;

% 3. 各块组数不等，并包含完全不可用资源，混合进制索引无遗漏。
available=logical([1,1,0;1,0,0;1,1,0]);
beams=[1,1,0;1,0,0;2,2,0];
problem=toy_problem([3,5,0;4,0,0;2,1,0],[10;10;10],2,beams,available);
r=leo_exhaustive_search(problem,o);oracle=binary_oracle(problem);
assert(isequal(r.estimate.groupsPerResource,[6,4,1]) && r.visitedSchedules==24);
assert(abs(r.fairness-oracle.fairness)<1e-12 && abs(r.totalBits-oracle.totalBits)<1e-10);
assert(~any(r.x(~available)));checks=checks+1;

% 4. 批次大小不影响穷举范围或严格字典序结果。
o.batchSize=1;a=leo_exhaustive_search(problem,o);
o.batchSize=7;b=leo_exhaustive_search(problem,o);
assert(a.visitedSchedules==b.visitedSchedules && isequal(a.x,b.x));
assert(a.fairness==b.fairness && a.totalBits==b.totalBits);checks=checks+1;

% 5. 单用户累计服务比例也不封顶；q_i不是服务截断值。
problem=toy_problem([1,10],1,1,[1,1],true(1,2));
r=leo_exhaustive_search(problem,o);
assert(abs(r.fairness-11)<1e-10 && abs(r.totalBits-11)<1e-10 && all(r.x(:)));
assert(r.stage1Complete && r.stage2Complete);checks=checks+1;

% 6. 一个用户永远不可服务时公平为 0，仍应做第二阶段吞吐比较。
problem=toy_problem([2,3;0,0],[1;1],1,[1,1;0,0],logical([1,1;0,0]));
r=leo_exhaustive_search(problem,o);
assert(r.completed && r.fairness==0 && abs(r.totalBits-5)<1e-10);
assert(isequal(r.x,logical([1,1;0,0])));checks=checks+1;

% 7. 整周期无可用用户：唯一空日程也是完整穷举，不能声称“零测试”。
problem=toy_problem(zeros(2,2),ones(2,1),1,zeros(2,2),false(2,2));
r=leo_exhaustive_search(problem,o);
assert(r.completed && r.hasIncumbent && r.visitedSchedules==1);
assert(r.fairness==0 && r.totalBits==0 && ~any(r.x(:)));checks=checks+1;

% 8. 规模/内存超限时不偷做小问题；没有搜索或最优性声明。
problem=toy_problem(ones(3,2),ones(3,1),2,repmat((1:3).',1,2),true(3,2));
limited=o;limited.maxSchedules=1;
r=leo_exhaustive_search(problem,limited);
assert(strcmp(r.status,'size_limit') && r.visitedSchedules==0 && ~r.completed);
assert(isempty(r.x) && isnan(r.fairness) && ~r.optimal && ~r.hasIncumbent);
limited=o;limited.maxMemoryBytes=1;r=leo_exhaustive_search(problem,limited);
assert(strcmp(r.status,'size_limit') && r.visitedSchedules==0);checks=checks+1;

% 9. 时间限制与最优性分开；零时间预算应明确返回未完成。
limited=o;limited.maxSeconds=0;
r=leo_exhaustive_search(problem,limited);
assert(strcmp(r.status,'time_limit') && ~r.completed && ~r.optimal && r.visitedSchedules==0);
assert(~r.stage1Complete && ~r.stage2Complete);checks=checks+1;

% 10. 默认大问题只计算规模：保留原 32 用户/20 块，不执行指数搜索。
legacy = leo_default_parameters(); legacy.statistics.serviceModel = 'slot_union';
model=run_leo_sinr(legacy);
r=leo_exhaustive_search(model.problem,o);
assert(r.estimate.resources==20 && r.estimate.log10Schedules>100);
assert(strcmp(r.status,'size_limit') && ~r.optimal && ~r.hasIncumbent);
assert(~r.estimate.countExactInDouble);checks=checks+1;
fprintf('PASS: %d exhaustive-baseline test groups.\n',checks);
end

function problem=toy_problem(bits,q,L,beamIndex,available)
% 直接指定可独立核对的原始设计功率，避免与生产枚举实现共用预计算。
K=size(bits,1);M=size(bits,2);
p=leo_default_parameters(); p.statistics.serviceModel = 'slot_union';p.system.K=K;p.system.maxStreams=L;
p.system.qosTargetBits=q;p.system.bandwidthHz=100;
p.time.nSlots=M;p.time.blockSlots=1;p.time.slotDurationS=1;
p.time.baseOverheadS=0;p.time.configOverheadS=0;
p=leo_validate_parameters(p);r=leo_build_resources(p);
b.available=available;b.index=beamIndex;
d.signalW=expm1(log(2)*bits/p.system.bandwidthHz);
d.noiseW=ones(K,M);
d.beamPowerW=zeros(K,max(1,max(beamIndex(:))),M);
for m=1:M
    for i=find(available(:,m)).'
        d.beamPowerW(i,beamIndex(i,m),m)=d.signalW(i,m);
    end
end
problem=leo_form_problem(p,r,b,d);
end

function best=binary_oracle(problem)
% 独立遍历原始 x(:) 的所有二元位串，逐点用既有完整日程评价器计算。
n=prod(problem.data.shape);assert(n<=12);
best.fairness=-Inf;best.totalBits=-Inf;best.x=[];
for code=0:2^n-1
    vector=logical(bitget(code,1:n).');
    if any(vector>problem.hard.upper) || any(problem.hard.A*double(vector)>problem.hard.rhs)
        continue;
    end
    x=reshape(vector,problem.data.shape);
    s=problem.evaluate(x);
    if s.fairness>best.fairness || (s.fairness==best.fairness && s.totalBits>best.totalBits)
        best.fairness=s.fairness;best.totalBits=s.totalBits;best.x=x;
    end
end
end
