function result = leo_solve_original_search(problem,kind,options,provided)
%LEO_SOLVE_ORIGINAL_SEARCH 第 13.3 节：原始速率的 greedy/exchange/tabu 两阶段基线。
% 输入：原问题、方法名、与 SB 共用初始化/时间选项、共同提供日程。
% 输出：原始可行日程；禁忌轨迹允许暂时退步，保存结果与阶段 2 门槛严格验收。
if nargin<4, provided = []; end
assert(any(strcmp(kind,{'greedy','exchange','tabu','initial'})));
options = leo_method_options(options); previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
rng(options.seed,'twister'); budget.timer = tic; budget.seconds = options.maxSeconds;
initial = leo_initial_schedules(problem,provided,options,budget); best = initial;
data = problem.data; evaluations = 0;
cache = leo_prepare_upper_bounds(data);
upperF = leo_original_upper_bound(data,cache,ones(data.shape(1),1)/data.shape(1),'fairness');
for phaseIndex = 1:2
    localBudget = budget;
    if phaseIndex==1
        phase = 'fairness'; s0 = 0; localBudget.seconds = options.maxSeconds*options.fairnessBudgetFraction;
    else
        phase = 'throughput'; s0 = best.service.fairness;
        upperV = leo_original_upper_bound(data,cache,zeros(data.shape(1),1),'throughput',s0);
    end
    phaseStart = best.service; phaseIterations = 0;
    history = leo_record_search_step([],best.service,0,toc(budget.timer),evaluations);
    iterationKind = 'none';
    if strcmp(kind,'greedy')
        start = best;
        if phaseIndex==1, start.x = false(data.shape); start.service = problem.evaluate(start.x); end
        candidate = leo_original_greedy(problem,start,phase,s0,localBudget);
        % 构造轨迹与共同初始化择优，记录当时已知可行日程的成绩。
        construction = candidate.history; incumbent = phaseStart;
        for h = 2:numel(construction.iteration)
            point.fairness = construction.savedFairness(h); point.totalBits = construction.savedTotalBits(h);
            if point.fairness>incumbent.fairness || ...
                    (point.fairness==incumbent.fairness && point.totalBits>incumbent.totalBits)
                incumbent = point;
            end
            if strcmp(phase,'throughput')
                incumbent.fairness = construction.savedFairness(h); incumbent.totalBits = construction.savedTotalBits(h);
            end
            history = leo_record_search_step(history,incumbent,construction.iteration(h), ...
                construction.elapsedSeconds(h),evaluations+construction.evaluations(h));
        end
        phaseIterations = candidate.iterations; iterationKind = candidate.iterationKind;
        evaluations = evaluations+candidate.evaluations;
        if leo_service_is_better(candidate.service,best.service,phase,s0), best = candidate; end
    elseif ~strcmp(kind,'initial')
        current = best; tabuUntil = zeros(data.shape); stagnant = 0;
        iterationKind = [kind,'_round'];
        for iteration = 1:1000
            if leo_budget_expired(localBudget) || options.recoveryEvaluations==0, break; end
            before = best.service;
            if strcmp(kind,'exchange')
                candidate = leo_recover_schedule(problem,current.x,phase,s0,options,iteration,localBudget);
                evaluations = evaluations+candidate.evaluations;
                if leo_service_is_better(candidate.service,current.service,phase,s0), current = candidate; end
            else
                pool = leo_original_neighbors(problem,current.x,current.service,options.recoveryEvaluations,iteration,localBudget);
                evaluations = evaluations+numel(pool); selected = 0;
                for k = 1:numel(pool)
                    s = pool(k).service;
                    if strcmp(phase,'throughput') && any(s.demandRatio<s0), continue; end
                    aspiration = leo_service_is_better(s,best.service,phase,s0);
                    if any(tabuUntil(pool(k).changed)>iteration) && ~aspiration, continue; end
                    if selected==0 || leo_service_is_better(s,pool(selected).service,phase,s0), selected = k; end
                end
                if selected>0
                    candidate = pool(selected); candidate.service = problem.evaluate(candidate.x);
                    if strcmp(phase,'fairness') || all(candidate.service.demandRatio>=s0)
                        tabuUntil(candidate.changed) = iteration+5;
                        current = candidate;
                    end
                end
            end
            if leo_service_is_better(current.service,best.service,phase,s0), best = current; end
            phaseIterations = iteration;
            history = leo_record_search_step(history,best.service,iteration,toc(budget.timer),evaluations);
            if leo_service_is_better(best.service,before,phase,s0), stagnant = 0;
            else, stagnant = stagnant+1; end
            if strcmp(kind,'exchange') && stagnant>=max(2,data.shape(2)), break; end
        end
    end
    stage.x = best.x; stage.service = best.service; stage.initialService = phaseStart;
    stage.history = history; stage.iterations = phaseIterations; stage.iterationKind = iterationKind;
    stage.elapsedAtEndSeconds = toc(budget.timer);
    if phaseIndex==1, result.stage1 = stage;
    else, result.stage2 = stage; result.fairnessFloor = s0; end
end
result.initial = initial; result.x = best.x; result.service = best.service; result.evaluations = evaluations;
result.fairnessUpperBound = upperF.value; result.fairnessGap = max(0,upperF.value-best.service.fairness);
result.throughputUpperBoundBits = upperV.value*data.referenceBits;
result.throughputGapBits = max(0,result.throughputUpperBoundBits-best.service.totalBits);
result.elapsedSeconds = toc(budget.timer); result.hardFeasible = true;
result.usesExhaustiveSolution = false; result.optimal = false;
end
