function test_leo_theory_bound()
%TEST_LEO_THEORY_BOUND 穷举小问题检查上界、完整波束定价、备份及无可行记录。
p=leo_default_parameters(); p.problem.objectiveMode='full_qos_sum'; p.system.K=3; p.system.maxStreams=2; p.time.nSlots=8;
p.time.blockSlots=4; p.system.bandwidthHz=100; p.system.qosTargetBits=[.3;.4;.5]; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(3,2); b.available(1,2)=false;
b.index=repmat((1:3).',1,2); b.index(~b.available)=0;
c.noiseW=ones(3,8); link.signalW=repmat([8;6;10],1,8);
link.beamPowerW=repmat([8,.2,.4;.3,6,.1;.2,.3,10],1,1,8);
d=leo_prepare_design_service(p,r,b,c,link); problem=leo_form_problem(p,r,b,d); data=problem.data;
best=-Inf; bestX=[];
for code=0:63
    x=reshape(logical(bitget(code,1:6)),3,2);
    if any(x(:)>data.hard.upper) || any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
    s=problem.evaluate(x);
    if all(s.demandRatio>=1) && s.totalBits>best, best=s.totalBits; bestX=x; end
end
assert(isfinite(best));
report.problemData=data; report.parameters=p;
report.records=struct('method',{'exhaustive','empty'},'seed',{1,1},'status',{'completed','completed'});
report.solutions={struct('x',bestX),struct('x',false(3,2))};
t=leo_theory_bound(report,struct('maxSeconds',20,'maxIterations',50));
assert(t.pricingComplete && t.upperBits>=best-1e-7 && abs(t.lowerBits-best)<1e-8);
assert(t.recordFeasible(1) && ~t.recordFeasible(2));
assert(numel(t.blockTrace)==data.shape(2) && numel(t.iterationTrace)==t.pricingIterations);
if ~isempty(t.iterationTrace)
 assert(all(diff([t.iterationTrace.bestUpperBits])<=1e-5));
 assert(all([t.iterationTrace.bestUpperBits]>=best-1e-7));
end
u=leo_theory_bound(report,struct('maxSeconds',0));
assert(~u.pricingComplete && u.upperBits>=best-1e-7 && t.upperBits<=u.upperBits+1e-7);
report.theory=t; directory=tempname; mkdir(directory); cleanup=onCleanup(@() rmdir(directory,'s')); %#ok<NASGU>
leo_export_theory_bound(report,directory);
assert(exist(fullfile(directory,'theoretical_bound_by_run.csv'),'file')==2);
assert(exist(fullfile(directory,'theoretical_bound_summary.csv'),'file')==2);
assert(exist(fullfile(directory,'theoretical_bound_iterations.csv'),'file')==2);
assert(exist(fullfile(directory,'theoretical_bound_blocks.csv'),'file')==2);
save(fullfile(directory,'benchmark.mat'),'report','-v7');
[v,fig]=run_leo_theory_from_saved(fullfile(directory,'benchmark.mat'),struct('maxSeconds',0),false);
assert(isempty(fig) && v.upperBits>=best-1e-7);
fprintf('PASS: exact binary enumeration, common QoS-floor upper bound, UB1 fallback and saved-result recovery.\n');
end
