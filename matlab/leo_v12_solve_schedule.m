function result = leo_v12_solve_schedule(problem,proxy,options,initialSchedule)
%LEO_V12_SOLVE_SCHEDULE V12未封顶公平优先，原始设计模型上的两阶段启发式搜索。
% 接口标注：
% 输入：problem：原问题；proxy：可选已有代理；options：方法参数；initialSchedule：可选日程。
% 输出：result：两阶段日程、原始服务、严格公平门槛、有效差距与运行记录。
% 不调用穷举、不缩小物理候选域；每资源单独存储 QUBO/Ising。
% options.enabled 仅控制主入口；直接调用本函数始终执行。
if nargin<2, proxy = []; end
if nargin<3, options = struct(); end
if nargin<4, initialSchedule = []; end
options = leo_v8_method_options(options);
assert(leo_is_lexicographic(problem.data),'V12 solver requires the uncapped lexicographic objective.');
previousRng = rng; cleanup = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng(options.seed,'twister');
budget.timer = tic; budget.seconds = options.maxSeconds;
initial = leo_initial_schedules(problem,initialSchedule,options,budget);
cacheTimer=tic;
cache = leo_prepare_upper_bounds(problem.data);
upperSetupSeconds=toc(cacheTimer); initialProxySeconds=0;
if isempty(proxy) && ~leo_budget_expired(budget)
    proxyTimer=tic;
    if strcmp(options.referenceMode,'current_schedule')
        proxy = leo_v12_build_service_surrogates(problem,'current_schedule',initial.x);
    else
        proxy = leo_v12_build_service_surrogates(problem,options.referenceMode);
    end
    initialProxySeconds=toc(proxyTimer);
end
initialSeconds = toc(budget.timer);
if options.verbose
    fprintf('Lagrangian + %s, configuration A: %d users, %d resources, full physical candidates.\n', ...
        options.innerSolver,problem.data.shape(1),problem.data.shape(2));
    fprintf('  Initial (%s): fairness=%.9g, total=%.6g Mbit.\n', ...
        initial.bestName,initial.service.fairness,initial.service.totalBits/1e6);
end
fairBudget = budget; fairBudget.seconds = options.maxSeconds*options.fairnessBudgetFraction;
stage1 = leo_v12_run_price_phase(problem,proxy,cache,'fairness',initial,options,fairBudget);
% 第二阶段在阶段 1 保留日程处相切；正公平时它也是代理可行点。
% 周期模式 s0=0 时有符号代理可能更严格，仍保留原式可行日程验收。
stage2Proxy = [];
stage2ProxySeconds=0;
if ~leo_budget_expired(budget)
    proxyTimer=tic;
    stage2Proxy = leo_v12_build_service_surrogates(problem,'current_schedule',stage1.x);
    stage2ProxySeconds=toc(proxyTimer);
end
stage2 = leo_v12_run_price_phase(problem,stage2Proxy,cache,'throughput',stage1,options,budget);
assert(all(stage2.service.demandRatio>=stage1.service.fairness));
assert(stage2.service.totalBits>=stage1.service.totalBits);
result.kind = ['V12 uncapped lexicographic: two-stage Lagrangian + ',options.innerSolver,' + original-service recovery'];
result.options = options; result.initial = initial;
result.stage1 = stage1; result.stage2 = stage2;
result.x = stage2.x; result.service = stage2.service;
result.fairnessFloor = stage1.service.fairness;
result.stage1Fairness=stage1.service.fairness;
result.stage1FairnessGap=max(0,stage1.upperBound.value-result.stage1Fairness);
result.stage1Certified=stage1.certifiedWithinTolerance;
result.objectiveMode='lexicographic_max_min';
result.fairnessUpperBound = stage1.upperBound.value;
result.fairnessGap = max(0,result.fairnessUpperBound-result.service.fairness);
result.throughputUpperBoundBits = stage2.upperBound.value*problem.data.referenceBits;
result.throughputGapBits = stage2.absoluteGap*problem.data.referenceBits;
result.initializationSeconds = initialSeconds;
result.workloadSchemaVersion=1;
result.initialProxySeconds=initialProxySeconds; result.stage2ProxySeconds=stage2ProxySeconds;
result.upperBoundPreparationSeconds=upperSetupSeconds;
result.elapsedSeconds = toc(budget.timer);
result.optimal = false;             % 不用 SB 停滞/迭代次数冒充全局最优
result.certificateScope = 'Fairness: original P_F. Throughput: original P_V at achieved fixed s0 only.';
result.usesExhaustiveSolution = false;
result.hardFeasible = true;         % 原始评价器已验证每个保存的二元日程
if options.verbose
    fprintf('  Final: fairness=%.9g, throughput=%.6g Mbit, time=%.3f s.\n', ...
        result.service.fairness,result.service.totalBits/1e6,result.elapsedSeconds);
    fprintf('  Original valid bounds: fairness<=%.9g; throughput(s0)<=%.6g Mbit.\n', ...
        result.fairnessUpperBound,result.throughputUpperBoundBits/1e6);
end
end
