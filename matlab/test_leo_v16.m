function test_leo_v16()
% Deterministic convergence tests and fixed-batch serial/parallel equivalence.
[o,~]=V16_SETTINGS(); m=o.method;
assert(m.sbTrajectories==64 && m.parallel.enabled && m.convergence.enabled && m.iterationOnly);
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
previous=rng; cleanup=onCleanup(@()rng(previous)); rng(16001,'twister'); %#ok<NASGU>
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
fprintf('PASS: V16 64 trajectories, cumulative-window convergence, no cap at 120/60, original minimum rounds and exact energy-history aggregation.\n');
end
