function result = leo_solve_proxy_milp(problem,proxy,options,provided)
%LEO_SOLVE_PROXY_MILP 第 13.3 节：同一切线代理的直接 MILP 两阶段对照。
% 输入：原问题、初始代理、共用方法选项、共同提供日程；输出原始服务与独立有效界。
% 阶段 2 在阶段 1 保留日程处相切；MILP 最优只代表该固定代理最优。
if nargin<4, provided = []; end
options = leo_method_options(options); previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
rng(options.seed,'twister'); budget.timer = tic; budget.seconds = options.maxSeconds;
initial = leo_initial_schedules(problem,provided,options,budget);
best = initial; data = problem.data; strict = leo_requires_full_qos(data);
cache = leo_prepare_upper_bounds(data);
upperF = leo_original_upper_bound(data,cache,ones(data.shape(1),1)/data.shape(1),'fairness');
model = leo_form_proxy_milp(data,proxy.lower,'fairness',0);
phase1Seconds=options.maxSeconds*options.fairnessBudgetFraction;
if strict, phase1Seconds=options.maxSeconds; end
if strict && best.service.fairness==1, phase1Seconds=0; end
phase1 = leo_call_milp(model,phase1Seconds-toc(budget.timer));
if strcmp(phase1.status,'unavailable'), error('leo:solverUnavailable','Neither intlinprog nor GLPK is available.'); end
if ~isempty(phase1.z)
    x = reshape(round(phase1.z(1:prod(data.shape))),data.shape); service = problem.evaluate(x);
    if leo_service_is_better(service,best.service,'fairness',0), best.x = logical(x); best.service = service; end
end
if phase1.optimal
    upperF.value = min(upperF.value,min(1,-phase1.objective+proxy.error.optimalFairnessGapBound));
end
result.stage1.x = best.x; result.stage1.service = best.service; result.stage1.solver = phase1;
result.stage1.initialService = initial.service;
result.stage1.elapsedAtEndSeconds = toc(budget.timer);
result.stage1.iterationKind = 'branch_and_bound_nodes'; result.stage1.iterations = phase1.nodes;
s0 = best.service.fairness;
if strict, s0=1; end
phase2 = struct('z',[],'objective',NaN,'optimal',false,'status','time_limit','backend','', ...
    'called',false,'nodes',NaN);
if (~strict || best.service.fairness==1) && ~leo_budget_expired(budget)
    touch = leo_build_service_surrogates(problem,'current_schedule',best.x);
    if ~leo_budget_expired(budget)
        model = leo_form_proxy_milp(data,touch.lower,'throughput',s0);
        phase2 = leo_call_milp(model,budget.seconds-toc(budget.timer));
    end
end
if strict && best.service.fairness<1, phase2.status='not_started_full_qos_not_found'; end
if ~isempty(phase2.z)
    x = reshape(round(phase2.z(1:prod(data.shape))),data.shape); service = problem.evaluate(x);
    if leo_service_is_better(service,best.service,'throughput',s0), best.x = logical(x); best.service = service; end
end
upperV = leo_original_upper_bound(data,cache,zeros(data.shape(1),1),'throughput',s0);
result.initial = initial; result.x = best.x; result.service = best.service;
result.stage2.x = best.x; result.stage2.service = best.service; result.stage2.solver = phase2;
result.stage2.initialService = result.stage1.service;
result.stage2.elapsedAtEndSeconds = toc(budget.timer);
result.stage2.iterationKind = 'branch_and_bound_nodes'; result.stage2.iterations = phase2.nodes;
result.fairnessFloor = s0; result.fairnessUpperBound = upperF.value;
result.fairnessGap = max(0,upperF.value-best.service.fairness);
result.throughputUpperBoundBits = upperV.value*data.referenceBits;
result.throughputGapBits = max(0,result.throughputUpperBoundBits-best.service.totalBits);
if strict && best.service.fairness<1, result.throughputGapBits=NaN; end
result.elapsedSeconds = toc(budget.timer); result.optimal = false;
result.usesExhaustiveSolution = false; result.hardFeasible = true;
end
