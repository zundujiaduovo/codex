function test_leo_branch_price()
%TEST_LEO_BRANCH_PRICE 人为构造LP分数间隙，独立整数枚举验证真正的分支收紧。
p=leo_default_parameters(); p.statistics.serviceModel='slot_union';
p.system.K=2; p.system.maxStreams=1; p.time.nSlots=2; p.time.blockSlots=1;
p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p.system.bandwidthHz=1e6; p.system.qosTargetBits=1e6; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(2,2); b.index=repmat((1:2).',1,2);
d=struct('serviceModel','slot_union','signalW',repmat([1023;255],1,2), ...
 'noiseW',ones(2,2),'beamPowerW',zeros(2,2,2));
problem=leo_form_problem(p,r,b,d); best=-Inf; bestX=[];
for code=0:15
 x=reshape(logical(bitget(code,1:4)),2,2);
 if any(problem.data.hard.A*double(x(:))>problem.data.hard.rhs), continue; end
 s=problem.evaluate(x);
 if all(s.userBits>=problem.data.qosTargetBits) && s.totalBits>best, best=s.totalBits; bestX=x; end
end
assert(abs(best-18e6)<1e-5);
report=struct('problemData',problem.data,'parameters',p, ...
 'records',struct('method','enumeration','seed',1,'status','completed'), ...
 'solutions',{{struct('x',bestX)}});
t=leo_theory_bound(report,struct('maxSeconds',30,'maxNodes',64,'relativeGap',1e-7,'absoluteGapBits',.01,'cappedService',false,'countCuts',false));
assert(t.rootLPConverged && t.rootRelaxationUpperBits>best+1e6);
assert(t.nodesProcessed>1 && t.upperBits>=best-1e-5 && t.upperBits-best<1);
assert(abs(t.lowerBits-best)<1e-5 && t.gapTargetMet);
assert(any([t.branchTrace.branchVariable]>0));
assert(all(diff([t.branchTrace.globalUpperBits])<=1e-3));
s=problem.evaluate(t.incumbentX); assert(all(s.userBits>=problem.data.qosTargetBits));
report.theory=t;
reused=leo_theory_bound(report,struct('maxSeconds',0,'verbose',false));
assert(reused.upperBits<=t.upperBits+1);
changed=report; changed.problemData.design.signalW(1,:)=4095;
fresh=leo_theory_bound(changed,struct('maxSeconds',0,'verbose',false));
assert(fresh.upperBits>=20e6 && fresh.lowerBits>=20e6-1e-5);
report=rmfield(report,'theory');
strengthened=leo_theory_bound(report,struct('maxSeconds',30,'verbose',false));
assert(strengthened.upperBits-best<1 && strengthened.upperBits>=best-1e-5);
% 3用户、2块、每块1人：分数可行、整数不可能全员达标。
p.system.K=3; p.system.qosTargetBits=.5e6; p.problem.referenceBits=[]; p=leo_validate_parameters(p);
b.available=true(3,2); b.index=repmat((1:3).',1,2);
d.signalW=ones(3,2); d.noiseW=ones(3,2); d.beamPowerW=zeros(3,3,2);
problem=leo_form_problem(p,r,b,d);
for code=0:63
 x=reshape(logical(bitget(code,1:6)),3,2);
 if any(problem.data.hard.A*double(x(:))>problem.data.hard.rhs), continue; end
 s=problem.evaluate(x); assert(any(s.userBits<problem.data.qosTargetBits));
end
report.problemData=problem.data; report.parameters=p; report.solutions={struct('x',false(3,2))};
t=leo_theory_bound(report,struct('maxSeconds',30,'maxNodes',128));
assert(isnan(t.lowerBits) && t.infeasibilityCertified && t.openNodeCount==0);
% 被预算截断的搜索只能给有效界，不能冒充闭合/不可行证明。
u=leo_theory_bound(report,struct('maxSeconds',0));
assert(~u.infeasibilityCertified && ~u.gapTargetMet && ~u.pricingComplete);
fprintf('PASS: nonzero LP/integer gap, branch closure to independent exact optimum, fractional-feasible/integer-infeasible case and budget truncation.\n');
end
