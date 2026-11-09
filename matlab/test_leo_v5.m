function test_leo_v5()
%TEST_LEO_V5 独立验证多级下界、精确离散尾概率及全员 QoS 阶段门控。
% 1. r(Z)>=min(1,Z/z*)r(z*)，独立公式覆盖噪声/干扰/衰落边界。
for S=[.1,2,20]
 for I=[0,.2,10]
  for zstar=[.25,1,2]
   z=linspace(0,4,301); rate=log2(1+z*S./(1+z*I));
   bound=min(1,z/zstar)*log2(1+zstar*S/(1+zstar*I));
   assert(all(rate>=bound-1e-12));
  end
 end
end
% 2. CDF 向低服务方向保守舍入；同 z*/tilt 多级 MGF 不大于二元门槛 MGF。
for zstar=[.25,.75,1]
 [u,w]=leo_fading_floor_distribution(zstar,10,4);
 [~,pbad]=leo_rician_power_cdf(zstar,10);
 for tau=[1,2.5,10,40]
  assert(sum(w.*exp(-tau*u))<=pbad+(1-pbad)*exp(-tau)+1e-12);
 end
end
p=leo_paper_parameters(); p.system.K=3; p.system.maxStreams=2;
p.time.nSlots=4; p.time.blockSlots=2; p.system.bandwidthHz=100;
p.system.qosTargetBits=[.05;.07;.09]; p.statistics.fadingLevels=4;
p=leo_validate_parameters(p); r=leo_build_resources(p);
b.available=true(3,2); b.index=repmat((1:3).',1,2);
c.noiseW=ones(3,4); link.signalW=repmat([8;6;10],1,4);
link.beamPowerW=repmat([8,.2,.4;.3,6,.1;.2,.3,10],1,1,4);
d=leo_prepare_design_service(p,r,b,c,link);
assert(all(d.calibrationBits>=d.legacyCalibrationBits-1e-12));
assert(any(d.selectedMultilevel));
problem=leo_form_problem(p,r,b,d); data=problem.data;
proxy=leo_build_service_surrogates(problem); cache=leo_prepare_upper_bounds(data);
% 独立枚举 5^4 个离散衰落样本，检查所有 49 个合法二元日程。
patterns=zeros(5^4,4); codes=(0:5^4-1).';
for t=1:4, patterns(:,t)=mod(floor(codes/5^(t-1)),5)+1; end
allX={}; totals=[]; fairness=[];
for code=0:63
 x=reshape(logical(bitget(code,1:6)),3,2);
 if any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
 s=problem.evaluate(x); allX{end+1}=x; totals(end+1)=s.totalBits; fairness(end+1)=s.fairness; %#ok<AGROW>
 for m=1:2
  assert(max(abs(leo_resource_service(data,m,x(:,m))-s.resourceBits(:,m)))<1e-12);
  assert(max(abs(leo_resource_group_services(data,m,x(:,m))-s.resourceBits(:,m)))<1e-12);
 end
 for i=1:3
  probs=ones(5^4,1);
  for t=1:4, probs=probs.*reshape(d.fadingMass(i,patterns(:,t)),[],1); end
  raw=s.slotBits(i,:)/d.serviceScale(i);
  values=reshape(d.fadingLevels(patterns),size(patterns))*raw.';
  actualFailure=sum(probs(values<s.userBits(i)-1e-12));
  assert(actualFailure<=d.userRisk(i)+1e-12);
 end
 cert=leo_certify_period_qos(data,x,s.userBits);
 assert(cert.jointFailureUpper<=p.statistics.totalRisk+1e-11);
 bounds=leo_evaluate_service_bounds(problem,proxy,x);
 assert(all(max(0,bounds.lower.userBits)<=s.userBits+1e-12));
 assert(all(s.userBits<=max(0,bounds.upper.userBits)+1e-12));
end
assert(any(fairness==1));
upper=leo_original_upper_bound(data,cache,zeros(3,1),'throughput',1);
assert(upper.value*data.referenceBits>=max(totals(fairness==1))-1e-12);
% 精确全局定价上界必须覆盖独立二元枚举的全 QoS 最优值。
report.problemData=data; report.parameters=p;
for j=1:numel(allX)
 report.records(j)=struct('method','enumeration','seed',1,'status','completed');
 report.solutions{j}=struct('x',allX{j});
end
theory=leo_theory_bound(report,struct('maxSeconds',5));
assert(theory.upperBits>=max(totals(fairness==1))-1e-12);
assert(abs(theory.lowerBits-max(totals(fairness==1)))<1e-12);
% 已知全员达标起点：公平阶段不再运行，未使用的公平代理不计入方法。
model=struct('problem',problem,'parameters',p,'xExample',problem.precheck.witness,'surrogate',proxy);
model.timings=struct('physicalProblemSeconds',.001,'proxySeconds',.5);
opts=struct('methods',{{'initial','price_sb','sb_zero','price_sb_light'}}, ...
 'seeds',17,'budgetSeconds',2,'exhaustive',false,'makePlots',false,'verbose',false, ...
 'method',struct('fairnessRounds',2,'throughputRounds',1,'sbSteps',10,'sbTrajectories',2, ...
 'recoveryEvaluations',12,'recoveryPasses',1,'randomInitialSchedules',0,'verbose',false));
ready=leo_benchmark_case(model,opts);
assert(all(strcmp({ready.records.status},'completed')) && all([ready.records.fullQosFeasible]));
assert(all([ready.records.proxyPreparationSeconds]==0));
for j=2:numel(ready.solutions)
 assert(ready.solutions{j}.stage1.rounds==0);
 assert(isequal(ready.solutions{j}.initial.x,ready.solutions{1}.initial.x));
end
% 3. 明确不可达的需求：算法返回诊断，但不得启动降低门槛的吞吐阶段。
p.system.qosTargetBits=repmat(1e6,3,1); p.problem.referenceBits=[]; p=leo_validate_parameters(p);
problem=leo_form_problem(p,r,b,d); proxy=leo_build_service_surrogates(problem);
model=struct('problem',problem,'parameters',p,'xExample',problem.precheck.witness,'surrogate',proxy);
model.timings=struct('physicalProblemSeconds',.001,'proxySeconds',.001);
opts=struct('methods',{{'initial','original_exchange','original_tabu','price_sb','price_sb_light','price_local_adaptive'}}, ...
 'seeds',17,'budgetSeconds',1,'exhaustive',false,'makePlots',false,'verbose',false, ...
 'method',struct('fairnessRounds',2,'throughputRounds',2,'sbSteps',10,'sbTrajectories',2, ...
 'recoveryEvaluations',12,'recoveryPasses',1,'randomInitialSchedules',0,'verbose',false));
if exist('glpk','file')~=0 || exist('intlinprog','file')~=0, opts.methods{end+1}='proxy_milp'; end
report=leo_benchmark_case(model,opts);
assert(all(strcmp({report.records.status},'completed')));
assert(all(strcmp({report.records.goalStatus},'full_qos_not_found')));
assert(all(isnan([report.records.feasibleTotalBits])) && all(isnan([report.records.throughputGapBits])));
for j=1:numel(report.solutions)
 sol=report.solutions{j}; assert(isequal(sol.stage1.x,sol.stage2.x) && sol.fairnessFloor==1);
end
[~,values]=leo_plot_method_comparison(report,tempdir,false);
assert(all(isnan(values.median(:,3))));
% MATLAB 备用恢复脚本也不得把未达标日程放入正式吞吐栏。
recoveryDirectory=tempname; mkdir(recoveryDirectory);
cleanup=onCleanup(@() rmdir(recoveryDirectory,'s')); %#ok<NASGU>
save(fullfile(recoveryDirectory,'raw_benchmark.mat'),'report','-v7');
comparisonRoot=fileparts(fileparts(mfilename('fullpath'))); comparisonRender=false;
run(fullfile(comparisonRoot,'RECOVER_COMPARISON.m'));
assert(all(isnan(comparisonValues(3,:))));
theory=leo_theory_bound(report,struct('maxSeconds',0)); assert(isnan(theory.lowerBits));
stage=problem.makeStage2(problem.precheck.witness); assert(stage.s0==1);
fprintf('PASS: V5 multilevel rate floor, exact discrete tails for all schedules, original/proxy/upper consistency and strict full-QoS gating.\n');
end
