function test_leo_surrogate()
%TEST_LEO_SURROGATE 凸性、minimax、硬约束干扰区间、二次系数、参考点和边界检查。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
checks = 0;

% 1. T1 导数与独立差分；含物理 W 尺度与标准化尺度。
for N = [1,1e-14]
    S = 2*N; B = 100; I = .7*N; h = 1e-4*N;
    [r,dr,d2r] = leo_rate_and_derivatives(S,N,B,I);
    rp = B*log2(1+S/(N+I+h)); rm = B*log2(1+S/(N+I-h));
    assert(dr<0 && d2r>0);
    assert(abs((rp-rm)/(2*h)/dr-1)<1e-7);
    assert(abs((rp-2*r+rm)/h^2/d2r-1)<1e-6);
end
checks=checks+1;

% 2. 弦两端精确，切线相切，完整区间上下夹逼，minimax 两端误差相等。
S=2;N=1;B=100;a=.3;b=10;
chord=leo_chord_upper(S,N,B,a,b);
tangent=leo_tangent_lower(S,N,B,chord.minimaxReferenceW);
I=linspace(a,b,1001); exact=leo_rate_and_derivatives(S,N,B,I);
lower=tangent.alphaBps-tangent.omegaBpsPerW*I;
upper=chord.alphaBps-chord.omegaBpsPerW*I;
assert(all(lower<=exact+1e-10) && all(exact<=upper+1e-10));
assert(max(abs(upper([1,end])-exact([1,end])))<1e-10);
assert(abs(tangent.omegaBpsPerW/chord.omegaBpsPerW-1)<1e-12);
assert(abs((exact(1)-lower(1))-(exact(end)-lower(end)))<1e-10);
assert(max(exact-lower)<=chord.maxGapBps+1e-10);
assert(chord.maxGapBps<=chord.curvatureGapBoundBps+1e-10);
checks=checks+1;

% 3. 与区间内其他切点比较，minimax 的最大端点误差不更大。
for point=linspace(a,b,21)
    alternative=leo_tangent_lower(S,N,B,point);
    maxGap=max(exact([1,end])-(alternative.alphaBps-alternative.omegaBpsPerW*[a,b]));
    assert(chord.maxGapBps<=maxGap+1e-10);
end
checks=checks+1;

% 4. 极小物理功率绝不能按 eps 当作零；同时检验功率缩放不变性。
original=leo_chord_upper(2,1,20e6,0,5);
tiny=leo_chord_upper(2e-15,1e-15,20e6,0,5e-15);
assert(tiny.maxGapBps>0 && tiny.minimaxReferenceW>0 && tiny.minimaxReferenceW<5e-15);
assert(abs(tiny.alphaBps/original.alphaBps-1)<1e-12);
assert(abs(tiny.omegaBpsPerW*1e-15/original.omegaBpsPerW-1)<1e-12);
assert(abs(tiny.minimaxReferenceW/1e-15-original.minimaxReferenceW)<1e-12);
short=leo_chord_upper(2,1,1,0,1e-12);
assert(short.minimaxReferenceW>0 && short.minimaxReferenceW<1e-12);
assert(abs(short.minimaxReferenceW/1e-12-.5)<1e-10);
checks=checks+1;

% 5. S=0、退化区间精确处理；不从 0/0 产生 NaN。
zero=leo_chord_upper(0,1e-14,20e6,0,1e-13);
assert(zero.alphaBps==0 && zero.omegaBpsPerW==0 && zero.maxGapBps==0);
point=leo_chord_upper(2,1,100,.7,.7);
assert(point.minimaxReferenceW==.7 && point.maxGapBps==0);
assert(abs(point.alphaBps-leo_rate_and_derivatives(2,1,100,.7))<1e-12);
checks=checks+1;

% 6. 负切线保持原值；与强干扰下合法多人组的二次服务一致。
problem=toy_problem(2,2,false);
data=problem.data;
data.design.signalW(:)=1;data.design.noiseW(:)=1;
for t=1:4, data.design.beamPowerW(:,:,t)=[1,100,0;100,1,0]; end
problem.data=data;problem.evaluate=@(x) leo_evaluate_service(data,x);
proxy=leo_build_service_surrogates(problem);
bounds=leo_evaluate_service_bounds(problem,proxy,true(2,2));
assert(any(bounds.lower.userBits<0) && bounds.lower.fairness<0);
assert(bounds.sandwichValid && ~bounds.lower.nonnegativeQoSFeasible);
checks=checks+1;

% 7. Imax 必须排除自身波束、按不同波束只计一次，并只取 L-1 项。
problem=toy_problem(4,2,true);
proxy=leo_build_service_surrogates(problem);data=problem.data;
for t=1:4
    expected=max(data.design.beamPowerW(1,2:3,t));
    assert(abs(proxy.limits.maxW(1,t)-expected)<1e-12);
end
for m=1:2
    groups=leo_enumerate_resource_groups(data,m,100);
    for g=1:size(groups,2)
        x=false(4,2);x(:,m)=groups(:,g);I=leo_schedule_interference(data,x);
        for t=find(data.slotToResource==m)
            selected=groups(:,g);
            assert(all(I(selected,t)<=proxy.limits.maxW(selected,t)+1e-12));
        end
    end
end
checks=checks+1;

% 8. 二次 a/b 与逐槽仿射率独立累加相等，b>=0、自对角为零。
x=problem.precheck.witness;
I=leo_schedule_interference(data,x);manualLow=zeros(4,2);manualUp=manualLow;
for t=1:4
    m=data.slotToResource(t);
    manualLow(:,m)=manualLow(:,m)+data.dataDurationS(t)*x(:,m).* ...
        (proxy.tangent.alphaBps(:,t)-proxy.tangent.omegaBpsPerW(:,t).*I(:,t));
    manualUp(:,m)=manualUp(:,m)+data.dataDurationS(t)*x(:,m).* ...
        (proxy.chord.alphaBps(:,t)-proxy.chord.omegaBpsPerW(:,t).*I(:,t));
end
bounds=leo_evaluate_service_bounds(problem,proxy,x);
assert(max(abs(manualLow(:)-bounds.lower.resourceBits(:)))<1e-10);
assert(max(abs(manualUp(:)-bounds.upper.resourceBits(:)))<1e-10);
assert(all(proxy.lower.bBits(:)>=0) && all(proxy.upper.bBits(:)>=0));
for m=1:2
    assert(all(diag(proxy.lower.bBits(:,:,m))==0) && all(diag(proxy.upper.bBits(:,:,m))==0));
end
checks=checks+1;

% 9. 当前点相切对每用户周期服务精确；未选用户仍取合法 minimax 点。
touch=leo_build_service_surrogates(problem,'current_schedule',x);
bounds=leo_evaluate_service_bounds(problem,touch,x);
assert(max(abs(bounds.lowerGapBits))<1e-10);
report=leo_check_surrogate_groups(problem,touch);assert(report.allGroupsPassed);
one=toy_problem(2,1,false);x0=logical([0,0;1,1]);
I=leo_schedule_interference(one.data,x0);
touch=leo_build_service_surrogates(one,'current_schedule',x0);
assert(any(I(1,:)>touch.limits.maxW(1,:)) && all(touch.referenceW(1,:)==0));
checks=checks+1;

% 10. L=1 时合法组没有干扰，下界/原式/上界均精确；不可用和无数据槽为零。
report=leo_check_surrogate_groups(one,touch);assert(report.maxLowerGapBits<1e-10);
dead=one;dead.data.available(:)=false;dead.data.beamIndex(:)=0;
dead.data.hard.upper(:)=0;dead.data.dataDurationS(:)=0;
dd=dead.data;dead.evaluate=@(xx) leo_evaluate_service(dd,xx);
z=leo_build_service_surrogates(dead);
assert(all(z.lower.aBits(:)==0) && all(z.lower.bBits(:)==0));
assert(all(z.upper.aBits(:)==0) && all(z.error.lowerUserBits==0));
checks=checks+1;

% 11. 独立全二元位串枚举，检查误差预算及 E2；非法分数日程拒绝证书。
data=problem.data;num=0;
for code=0:255
    v=logical(bitget(code,1:8).');
    if any(data.hard.A*double(v)>data.hard.rhs),continue;end
    result=leo_evaluate_service_bounds(problem,proxy,reshape(v,4,2));
    assert(all(result.lowerGapBits<=proxy.error.lowerUserBits+1e-10));num=num+1;
end
assert(num==100);
failed=false;
try,leo_evaluate_service_bounds(problem,proxy,.5*ones(4,2));catch,failed=true;end
assert(failed);checks=checks+1;

% 12. 真实 8 用户/3 块算例逐资源遍历全部 768 个组；加性覆盖所有完整日程。
p=leo_default_parameters(); p.statistics.serviceModel = 'slot_union';p.system.K=8;p.time.nSlots=15;
model=run_leo_sinr(p);
report=leo_check_surrogate_groups(model.problem,model.surrogate);
assert(report.allGroupsPassed && report.groupsChecked==768);
assert(abs(report.coveredFullScheduleLog10-log10(16777216))<1e-12);
checks=checks+1;
fprintf('PASS: %d tangent/chord test groups.\n',checks);
end

function problem=toy_problem(K,L,sharedBeam)
p=leo_default_parameters(); p.statistics.serviceModel = 'slot_union';p.system.K=K;p.system.maxStreams=L;
p.system.bandwidthHz=100;p.system.qosTargetBits=10;
p.time.nSlots=4;p.time.blockSlots=2;p.time.slotDurationS=.5;
p.time.baseOverheadS=0;p.time.configOverheadS=0;
p=leo_validate_parameters(p);r=leo_build_resources(p);
b.available=true(K,2);b.index=repmat((1:K).',1,2);
if sharedBeam,b.index=repmat([1;1;2;3],1,2);end
signal=[1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.signalW=signal(1:K,:);d.noiseW=repmat([1,2,1.5,3],K,1);
d.beamPowerW=zeros(K,max(3,K),4);
for t=1:4
    C=[2,5,3,1;2,1,4,3;5,1,2,4;3,4,5,2]*(1+.1*t);
    d.beamPowerW(:,:,t)=C(1:K,1:max(3,K));
    for i=1:K,d.beamPowerW(i,b.index(i,1),t)=d.signalW(i,t);end
end
problem=leo_form_problem(p,r,b,d);
end
