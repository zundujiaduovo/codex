function test_leo_v17()
% Deterministic convergence tests and fixed-batch serial/parallel equivalence.
previous=rng; cleanup=onCleanup(@()rng(previous)); rng(17001,'twister'); %#ok<NASGU>
[o,~]=V17_SETTINGS(); m=o.method;
assert(m.sbTrajectories==64 && m.parallel.enabled && m.convergence.enabled && m.iterationOnly);
% Regression: the user's V16 1400-round solution must survive a sum-only gain.
incumbent=struct('fairness',2.72018229,'totalBits',229.122e6,'demandRatio',2.72018229);
candidate=struct('fairness',2.71911328,'totalBits',229.225e6,'demandRatio',2.71911328);
rule=leo_v17_accept_phase('throughput',m); assert(strcmp(rule,'fairness'));
assert(~leo_service_is_better(candidate,incumbent,rule,2.718));
candidate.fairness=2.721; candidate.demandRatio=2.721; candidate.totalBits=220e6;
assert(leo_service_is_better(candidate,incumbent,rule,2.718)); % retain higher fairness even at lower sum
control=m; control.coordination.stage2Floor=2.718;
assert(strcmp(leo_v17_accept_phase('throughput',control),'throughput'));
assert(~leo_service_is_better(candidate,incumbent,'throughput',2.718));
% Every interrupted proxy reference must still enclose the exhaustive optimum.
for trial=1:12
    n=7; A=randn(n,1); B=randn(n); B=(B+B.')/2; B(1:n+1:end)=0;
    proxyQ=struct('nUsers',n,'A',A,'B',B,'beamIndex',[1;1;2;3;3;4;5],'maxStreams',3);
    optimum=-Inf;
    for mask=0:2^n-1
        x=logical(bitget(mask,1:n)).';
        if nnz(x)>3 || numel(unique(proxyQ.beamIndex(x)))<nnz(x), continue; end
        z=double(x); optimum=max(optimum,A.'*z-z.'*B*z/2);
    end
    partial=leo_v17_qubo_reference(proxyQ,false(n,1),1);
    full=leo_v17_qubo_reference(proxyQ,false(n,1),10000);
    assert(partial.lower<=optimum+1e-9 && partial.upper>=optimum-1e-9);
    assert(full.closed && abs(full.lower-optimum)<1e-9 && full.upper>=optimum-1e-9);
end
a=leo_v17_gain_audit([.1,.2,-.1],[.1,-.2,-.1],1e-7);
assert(a.signReversals==1 && a.maxRelativeError==2);
[problem,~]=leo_test_problem(); d=problem.data;
short=m; short.parallel.enabled=false; short.convergence.enabled=false; short.verbose=false;
short.originalFairnessRounds=1; short.originalThroughputRounds=3; short.fairnessRounds=2; short.throughputRounds=2;
short.sbSteps=20; short.sbTrajectories=4; short.localRestarts=4;
short.searchPolicy.fairnessEscapes=0; short.audit.enabled=false;
original=leo_solve_original_search(problem,'tabu',short,[]);
assert_retained(original);
short.innerSolver='local'; approximate=leo_v12_solve_schedule(problem,[],short,[]); assert_retained(approximate);
% Counterfactual/current and calibrated tangents remain lower bounds on every legal group.
x=original.stage1.x; service=problem.evaluate(x); proxy=leo_v12_build_service_surrogates(problem,'current_schedule',x);
groups=false(d.shape(1),0);
for mask=0:2^d.shape(1)-1
    g=logical(bitget(mask,1:d.shape(1))).';
    if nnz(g)<=d.maxStreams && numel(unique(d.beamIndex(g,1)))==nnz(g), groups(:,end+1)=g; end
end
ctx=struct('group',x(:,1),'service',service); w=ones(d.shape(1),1)./d.qosTargetBits;
[calibrated,diagnosis]=leo_v17_calibrate_tangent(d,proxy,1,w,ctx,groups);
z=double(groups); lower=z.*bsxfun(@minus,calibrated.aBits(:,1),calibrated.bBits(:,:,1)*z);
actual=leo_resource_group_services(d,1,groups);
assert(all(lower(:)<=actual(:)+1e-8*max(1,abs(actual(:)))));
assert(diagnosis.after<=diagnosis.before+1e-12);
short.searchPolicy.escapeRounds=3; short.searchPolicy.escapeCandidates=20;
rescue=leo_v17_fairness_escape(problem,struct('x',x,'service',service),short,1,[]);
assert(rescue.service.fairness>=service.fairness && rescue.evaluations>0);
problem.evaluate(rescue.x);
service=struct('fairness',2,'normalizedThroughput',4);
[s,done]=leo_v16_convergence_step(m,'fairness',service,0,[]);
for k=1:299
    [s,done]=leo_v16_convergence_step(m,'fairness',service,k,s); assert(~done);
end
[s,done]=leo_v16_convergence_step(m,'fairness',service,300,s); assert(done && s.stableWindows==3);
% Small per-round changes must accumulate over a whole window, rather than
% being ignored individually. A still-improving trajectory must not stop.
[s,~]=leo_v16_convergence_step(m,'fairness',service,0,[]);
for k=1:1200
    service.fairness=2+1e-6*k;
    [s,done]=leo_v16_convergence_step(m,'fairness',service,k,s); assert(~done);
end
service.fairness=2; [s,~]=leo_v16_convergence_step(m,'fairness',service,0,[],'original');
for k=1:1999, [s,done]=leo_v16_convergence_step(m,'fairness',service,k,s,'original'); assert(~done); end
[~,done]=leo_v16_convergence_step(m,'fairness',service,2000,s,'original'); assert(done);
q=struct('nUsers',4,'A',[4;3;2;1],'B',.2*(ones(4)-eye(4)), ...
    'beamIndex',(1:4).','maxStreams',2,'capacityIncluded',true,'slackWeights',[1;2]);
q=leo_v14_encode_qubo(q,1.2); seeds=[leo_encode_group_bits(q,logical([1;1;0;0])),leo_encode_group_bits(q,false(4,1))];
m.sbSteps=20; m.coordination.sbMinSteps=10; m.coordination.sbStagnationSteps=10;
rng(16001,'twister');
before=rng; serial=leo_v16_parallel_sb(q,m,seeds,'adaptive',false);
assert(size(serial.bits,2)==64 && serial.trajectories==64 && serial.parallelTasks==8);
ising=leo_qubo_to_ising(q); spin=2*serial.bits-1;
energy=ising.constant+ising.h.'*spin+sum(spin.*(ising.J*spin),1)/2;
assert(max(abs(energy-serial.energy))<1e-9);
assert(max(abs(serial.history.median-median(serial.energyByTrajectory,1)))<1e-12);
if exist('parpool','file')>0 && license('test','Distrib_Computing_Toolbox')
    leo_v16_prepare_parallel(m.parallel); rng(before);
    parallel=leo_v16_parallel_sb(q,m,seeds,'adaptive',true);
    assert(isequal(serial.bits,parallel.bits) && isequal(serial.energy,parallel.energy));
    assert(isequal(serial.energyByTrajectory,parallel.energyByTrajectory));
    assert(parallel.parallelWorkers>=2);
    fprintf('PASS: real parfor results equal the same serial reference batches.\n');
else
    fprintf('NOT RUN: worker equivalence requires Parallel Computing Toolbox; production parallel mode reports this requirement explicitly.\n');
end
fprintf('PASS: V17 fairness-retention regression, fixed-floor control, interrupted/exhaustive QUBO bounds, 64 trajectories, cumulative-window stopping and energy-history aggregation.\n');
end

function assert_retained(result)
first=result.stage1.history.savedFairness; second=result.stage2.history.savedFairness;
assert(result.service.fairness>=max([first,second])-1e-12);
assert(all(result.service.demandRatio>=result.fairnessFloor));
assert(result.service.fairness>=result.initial.service.fairness);
assert(all(diff(first)>=-1e-12) && all(diff(second)>=-1e-12));
assert(numel(result.stage1.segments)==result.phaseCycles && numel(result.stage2.segments)==result.phaseCycles);
end
