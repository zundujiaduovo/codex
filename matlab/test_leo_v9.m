function test_leo_v9()
%TEST_LEO_V9 原目标候选筛选、两块 QoS 补偿、无二次 Tabu、缓存与消融。
o=leo_method_options(struct('verbose',false,'maxSeconds',3,'fairnessRounds',2, ...
 'throughputRounds',2,'originalSearchRounds',2,'sbSteps',20,'sbTrajectories',4, ...
 'randomInitialSchedules',0,'recoveryEvaluations',12,'recoveryPasses',1,'polishMoves',2));
problem=fixture(2,0); x=logical([1,1;0,1]); start=problem.evaluate(x);
inner.x=x(:,1); inner.candidateGroups=[x(:,1),logical([0;1])]; inner.candidateSources={'warm_start','sb'};
selected=leo_accept_resource_candidates(problem,x,start,1,inner,'throughput',1,[]);
assert(selected.accepted && selected.nonProxyWinner && selected.service.totalBits>start.totalBits);
assert(all(selected.service.demandRatio>=1) && strcmp(selected.source,'sb'));

% 两个单独替换均违反 QoS；同时替换可从4提高到6，独立完整评价复核。
problem=fixture(1,0); x=logical(eye(2)); start=problem.evaluate(x); banks={logical([0;1]),logical([1;0])};
for m=1:2
 inner.x=x(:,m); inner.candidateGroups=banks{m}; inner.candidateSources={'sb'};
 single=leo_accept_resource_candidates(problem,x,start,m,inner,'throughput',1,[]);
 assert(~single.accepted);
end
joint=o; joint.jointPairsPerTrigger=1;
r=leo_joint_candidate_search(problem,struct('x',x,'service',start),banks,'throughput',1,joint,1,[]);
assert(r.accepted==1 && all(r.service.demandRatio>=1) && abs(r.service.totalBits-6)<1e-12);
exact=problem.evaluate(r.x); assert(isequal(exact.userBits,r.service.userBits));

% 缓存只重用固定模型的静态量，结果与全量计算相同；不同模型拒绝重用。
problem=fixture(2,.3); x=logical(eye(2));
old=leo_build_service_surrogates(problem,'current_schedule',x);
cached=leo_build_service_surrogates(problem,'current_schedule',true(2),old);
fresh=leo_build_service_surrogates(problem,'current_schedule',true(2));
assert(isequaln(cached.lower,fresh.lower) && isequaln(cached.upper,fresh.upper));
different=problem; different.data.design.signalW(1)=different.data.design.signalW(1)*2;
failed=false; try, leo_build_service_surrogates(different,'current_schedule',x,old); catch, failed=true; end
assert(failed);

% 吞吐阶段真正使用指定参考模式，而不是全部覆盖成 current_schedule。
methods={'sb_zero','sb_minimax_fixed','sb_current_fixed'}; modes={'zero','minimax','current_schedule'};
reference=cell(1,3);
for j=1:3
 r=leo_run_benchmark_method(problem,old,x,methods{j},o);
 assert(strcmp(r.stage2.proxy.referenceMode,modes{j})); reference{j}=r.stage2.proxy.referenceW;
end
assert(any(reference{1}(:)~=reference{2}(:)));

% 原目标 Tabu 整个 benchmark 调用期间，二次代理/QUBO 构造器均禁止访问。
shadow=tempname; mkdir(shadow); create_blocker('leo_build_service_surrogates'); create_blocker('leo_build_resource_qubo');
addpath(shadow,'-begin'); clear leo_build_service_surrogates leo_build_resource_qubo;
cleanup=onCleanup(@() unshadow(shadow)); %#ok<NASGU>
model=struct('problem',problem,'parameters',struct('seed',13),'xExample',x,'surrogate',[]);
model.timings=struct('physicalProblemSeconds',.001,'proxySeconds',0);
opts=struct('methods',{{'original_tabu','original_tabu_independent'}},'seeds',13, ...
 'budgetSeconds',3,'exhaustive',false,'makePlots',false,'verbose',false,'method',o,'diagnosticSurrogates',false);
report=leo_benchmark_case(model,opts);
assert(all(strcmp({report.records.status},'completed')) && ~any([report.records.usesQuadraticProxy]));
assert(all([report.records.proxyPreparationSeconds]==0));
assert(report.solutions{1}.usesProvidedSchedule && ~report.solutions{2}.usesProvidedSchedule);
clear cleanup;

% SB/Local 成对使用同一候选池大小、刷新频率及联合协调开关。
for name={'price_sb_blockwise','price_local_blockwise','price_sb_joint','price_local_joint'}
 r=leo_run_benchmark_method(problem,[],x,name{1},o);
 assert(r.options.blockwiseOriginalAccept && r.options.refreshEvery==o.refreshEvery);
 assert(r.options.jointCandidateSearch==~isempty(strfind(name{1},'_joint')));
 assert(all(r.service.demandRatio>=1));
 assert(all(diff(r.stage2.history.savedTotalBits)>=-1e-10));
end
defaults=leo_benchmark_options(); assert(numel(defaults.methods)==8 && defaults.budgetSeconds==120);
assert(~any(ismember(defaults.methods,{'price_miqp','proxy_milp','sb_zero','sb_minimax_fixed','sb_current_fixed'})));

% 收敛图使用共同上界差距，原目标未达标点不进入吞吐/差距曲线。
data=struct('methods',{{'price_sb_blockwise'}},'representativeSeed',13,'shape',[2,2], ...
 'maxStreams',2,'requireFullQos',true,'events',struct([]),'energy',struct([]), ...
 'theoryBounds',struct('upperBits',10,'lowerBits',9.9));
data.progress=struct('method','price_sb_blockwise','seed',13,'seconds',1,'fairness',1,'totalBits',8);
s=leo_build_sb_convergence_specs(data); assert(abs(s(1).panels(2).series(1).y-20)<1e-12);
assert(isequal(s(1).panels(3).xlim,[0,15]));
data.progress.fairness=.9; s=leo_build_sb_convergence_specs(data);
assert(isnan(s(1).panels(2).series(1).y));
fprintf('PASS: V9 original-objective pool winner, joint QoS compensation, exact cache, active ablations, proxy-free Tabu, paired controls and gap plots.\n');
    function create_blocker(name)
        fid=fopen(fullfile(shadow,[name,'.m']),'w'); assert(fid>=0);
        fprintf(fid,'function varargout = %s(varargin)\nerror(''test:quadraticForbidden'',''Quadratic preprocessing must not be called by Tabu.'');\nend\n',name);
        fclose(fid);
    end
end
function unshadow(path)
rmpath(path); clear leo_build_service_surrogates leo_build_resource_qubo;
rmdir(path,'s');
end
function problem=fixture(limit,power)
p=leo_default_parameters(); p.problem.objectiveMode='full_qos_sum'; p.statistics.serviceModel='slot_union'; p.system.K=2;
p.system.maxStreams=limit; p.system.bandwidthHz=1; p.system.qosTargetBits=1;
p.problem.requireFullQos=true; p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1;
p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
resources=leo_build_resources(p); beams.available=true(2); beams.index=repmat([1;2],1,2);
design.signalW=[3,7;7,3]; design.noiseW=ones(2); design.beamPowerW=power*ones(2,2,2);
problem=leo_form_problem(p,resources,beams,design);
end
