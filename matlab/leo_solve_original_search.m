function result = leo_solve_original_search(problem,kind,options,provided)
%LEO_SOLVE_ORIGINAL_SEARCH 第 13.3 节：原始速率的 greedy/exchange/tabu 两阶段基线。
% 输入：原问题、方法名、与 SB 共用初始化/时间选项、共同提供日程。
% 输出：原始可行日程；禁忌轨迹允许暂时退步，保存结果与阶段 2 门槛严格验收。
if nargin<4, provided = []; end
assert(any(strcmp(kind,{'greedy','exchange','tabu','initial'})));
options = leo_method_options(options); previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
conv=leo_v16_convergence_options(); if isfield(options,'convergence'), conv=leo_v16_convergence_options(options.convergence); end
unlimited=conv.enabled;
rng(options.seed,'twister'); budget.timer = tic; budget.seconds = options.maxSeconds;
budget.iterationOnly=leo_iteration_only(options);
if budget.iterationOnly, budget.seconds=Inf; end
initial = leo_initial_schedules(problem,provided,options,budget); best = initial;
data = problem.data; evaluations = 0; strict = leo_requires_full_qos(data);
cache = leo_prepare_upper_bounds(data);
upperF = leo_original_upper_bound(data,cache,ones(data.shape(1),1)/data.shape(1),'fairness');
for phaseIndex = 1:2
    auditMoves={}; auditEnabled=isfield(options,'audit') && options.audit.enabled;
    phaseEvaluationStart=evaluations;
    localBudget = budget;
    phaseCap=options.originalSearchRounds;
    if phaseIndex==1 && isfield(options,'originalFairnessRounds'), phaseCap=options.originalFairnessRounds; end
    if phaseIndex==2 && isfield(options,'originalThroughputRounds'), phaseCap=options.originalThroughputRounds; end
    localBudget.maxIterations=phaseCap;
    if phaseIndex==1
        phase = 'fairness'; s0 = 0; localBudget.seconds = options.maxSeconds*options.fairnessBudgetFraction;
        if strict, localBudget.seconds=options.maxSeconds; end
    else
        phase = 'throughput'; s0 = best.service.fairness;
        if strict, s0=1; end
        upperV = leo_original_upper_bound(data,cache,zeros(data.shape(1),1),'throughput',s0);
    end
    phaseStart = best.service; phaseIterations = 0;
    [convergence,~]=leo_v16_convergence_step(options,phase,best.service,0,[],'original');
    bound=upperF.value; if phaseIndex==2, bound=upperV.value; end
    [stopping,stopStatus]=leo_search_stopping(options,phase,best.service,bound,toc(budget.timer),0);
    history = leo_record_search_step([],best.service,0,toc(budget.timer),evaluations);
    iterationKind = 'none';
    skipPhase = strict && ((phaseIndex==1 && best.service.fairness==1) || (phaseIndex==2 && best.service.fairness<1));
    if skipPhase || ~isempty(stopStatus)
        % 尚未达标时禁止按降低后的门槛优化吞吐。
    elseif strcmp(kind,'greedy')
        start = best;
        if phaseIndex==1, start.x = false(data.shape); start.service = problem.evaluate(start.x); end
        context=[];
        if stopping.options.enabled, context=struct('options',options,'upper',bound,'incumbent',phaseStart); end
        candidate = leo_original_greedy(problem,start,phase,s0,localBudget,context);
        stopStatus=candidate.stopStatus;
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
        iteration=0;
        while unlimited || iteration<phaseCap
            iteration=iteration+1;
            if leo_budget_expired(localBudget) || options.recoveryEvaluations==0, break; end
            if strict && phaseIndex==1 && best.service.fairness==1, break; end
            before = best.service;
            if auditEnabled, currentBefore=current; end
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
            if auditEnabled && strcmp(kind,'tabu') && leo_service_is_better(current.service,currentBefore.service,phase,s0)
                move=struct('iteration',iteration,'phase',phase,'floor',s0,'xBefore',currentBefore.x, ...
                    'xAfter',current.x,'seconds',toc(budget.timer));
                auditMoves{end+1}=move;
                if numel(auditMoves)>options.audit.tabuMoves, auditMoves(1)=[]; end
            end
            if leo_service_is_better(current.service,best.service,phase,s0), best = current; end
            phaseIterations = iteration;
            history = leo_record_search_step(history,best.service,iteration,toc(budget.timer),evaluations);
            if options.verbose && (iteration==1 || mod(iteration,100)==0 || iteration==phaseCap)
                limit=sprintf('%d',phaseCap); if unlimited, limit='until-convergence'; end
                fprintf('  %s %-10s %d/%s: fairness=%.9g, total=%.6g Mbit\n', ...
                    kind,phase,iteration,limit,best.service.fairness,best.service.totalBits/1e6);
            end
            [convergence,converged]=leo_v16_convergence_step(options,phase,best.service,iteration,convergence,'original');
            leo_v16_save_progress(options,phase,best.x,best.service,history,convergence,iteration);
            if unlimited && options.verbose && (mod(iteration,conv.windowRounds)==0 || converged)
                fprintf('    convergence: stable windows %d/%d, gain %.6g, tolerance %.6g, minimum rounds %d.\n', ...
                    convergence.stableWindows,conv.stableWindows,convergence.lastWindowGain, ...
                    convergence.lastWindowTolerance,convergence.minimumRounds);
            end
            if converged, stopStatus='objective_plateau'; break; end
            [stopping,stopStatus]=leo_search_stopping(options,phase,best.service,bound,toc(budget.timer),iteration,stopping);
            if ~isempty(stopStatus), break; end
            if leo_service_is_better(best.service,before,phase,s0), stagnant = 0;
            else, stagnant = stagnant+1; end
            if strcmp(kind,'exchange') && stagnant>=max(2,data.shape(2)), break; end
        end
    end
    stage.x = best.x; stage.service = best.service; stage.initialService = phaseStart;
    stage.history = history; stage.iterations = phaseIterations; stage.iterationKind = iterationKind;
    stage.evaluations=evaluations-phaseEvaluationStart;
    stage.elapsedAtEndSeconds = toc(budget.timer);
    stage.status='search_finished';
    if strcmp(kind,'initial'), stage.status='initialization_only';
    elseif leo_budget_expired(localBudget), stage.status='time_limit';
    elseif strcmp(kind,'greedy'), stage.status='no_improving_addition';
    elseif strcmp(kind,'exchange'), stage.status='stagnation';
    elseif phaseIterations>=phaseCap, stage.status='iteration_limit'; end
    if strcmp(kind,'greedy') && phaseIterations>=phaseCap, stage.status='iteration_limit'; end
    if ~isempty(stopStatus), stage.status=stopStatus; end
    if strict && phaseIndex==1 && phaseStart.fairness==1, stage.status='full_qos_already_met'; end
    if strict && phaseIndex==2 && best.service.fairness<1, stage.status='not_started_full_qos_not_found'; end
    [stopping,~]=leo_search_stopping(options,phase,best.service,bound,toc(budget.timer),phaseIterations,stopping);
    stopping.reason=stage.status; stopping.convergence=convergence; stage.stopping=stopping;
    if auditEnabled, stage.auditMoves=auditMoves; end
    if phaseIndex==1, result.stage1 = stage;
    else, result.stage2 = stage; result.fairnessFloor = s0; end
end
result.initial = initial; result.x = best.x; result.service = best.service; result.evaluations = evaluations;
result.fairnessUpperBound = upperF.value; result.fairnessGap = max(0,upperF.value-best.service.fairness);
result.throughputUpperBoundBits = upperV.value*data.referenceBits;
result.throughputGapBits = max(0,result.throughputUpperBoundBits-best.service.totalBits);
if strict && best.service.fairness<1, result.throughputGapBits=NaN; end
result.elapsedSeconds = toc(budget.timer); result.hardFeasible = true;
result.usesExhaustiveSolution = false; result.optimal = false;
result.usesQuadraticProxy=false;
result.usesProvidedSchedule=~isempty(provided);
end
