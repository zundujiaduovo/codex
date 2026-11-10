function result = leo_run_price_phase(problem,proxy,cache,phase,start,options,budget)
%LEO_RUN_PRICE_PHASE 两阶段共用价格循环；内层、恢复、原始验收和有效上界分开。
% 接口标注：
% 输入：problem/proxy/cache：模型、固定代理、有效界；phase/start/options/budget。
% 输出：result：阶段日程、价格/迭代/工作量轨迹、上界、停止状态及首次内层 sbTrace。
data = problem.data; K = data.shape(1); M = data.shape(2);
bestX = start.x; bestService = start.service; priceX = bestX;
isFairness = strcmp(phase,'fairness');
if isFairness
    lambda = ones(K,1)/K; s0 = 0;
    rounds = options.fairnessRounds; initialStep = options.fairnessStep;
else
    lambda = zeros(K,1); s0 = start.service.fairness;
    rounds = options.throughputRounds; initialStep = options.throughputStep;
    assert(all(start.service.demandRatio>=s0));
end
upper = leo_original_upper_bound(data,cache,lambda,phase,s0);
if isFairness && problem.precheck.forcedZeroFairness
    upper.value = 0; upper.kind = 'Positive-service max-flow proves zero fairness';
end
bestUpper = upper;
initialSeconds = toc(budget.timer); initialUpper = upper.value; firstSbTrace = [];
checkpoints=record_checkpoint([],bestService,0,initialSeconds,0,'initial');
history.lambda = zeros(K,rounds); history.lambdaNext = zeros(K,rounds);
history.lowerUserBits = zeros(K,rounds);
history.priceX = false(K,M,rounds);
fields = {'sAux','step','priceFairness','priceTotalBits','savedFairness','savedTotalBits', ...
    'upperBound','proxyEpoch','innerImprovement','resourcesSolved','sbSteps', ...
    'repairedCandidates','recoveryEvaluations','crossEvaluations','acceptedMoves','elapsedSeconds', ...
    'blockwiseEvaluations','blockwiseAccepted'};
for j = 1:numel(fields), history.(fields{j}) = zeros(1,rounds); end
history.completePriceRound = false(1,rounds);
epoch = 1; errors = NaN; touchErrors = NaN;
if ~isempty(proxy)
    errors = proxy.error.optimalFairnessGapBound; touchErrors = proxy.referenceTouchMaxAbsBits;
end
completed = 0; status = 'iteration_limit';
for k = 1:rounds
    if certified_gap(bestUpper.value,bestService,isFairness)<=options.gapTolerance
        status = 'bound_gap'; break;
    end
    if leo_budget_expired(budget), status = 'time_limit'; break; end
    [weights,sAux] = leo_price_weights(data,lambda,phase,s0);
    history.lambda(:,k) = lambda;
    improvement = 0; solved = 0; steps = 0; repairs = 0;
    blockwiseEvaluations = 0; blockwiseAccepted = 0;
    order = mod((0:M-1)+k-1,M)+1;
    for m = order
        if leo_budget_expired(budget), break; end
        inner = leo_solve_resource(data,proxy.lower,m,weights,priceX(:,m),options,budget);
        if isempty(firstSbTrace) && isfield(inner,'energyHistory')
            firstSbTrace.history = inner.energyHistory;
            firstSbTrace.resource = m; firstSbTrace.priceIteration = k;
            firstSbTrace.trajectories = inner.trajectories; firstSbTrace.energyScale = inner.energyScale;
        end
        if options.blockwiseOriginalAccept && (isFairness || s0>0)
            % 单块 SB 候选也拼到最佳日程上按原目标评分；第二阶段严格保留 QoS 门槛。
            % 价格日程仍保留原有整轮候选，两个路径都参与最终验收。
            if ~isequal(inner.x,bestX(:,m))
                bits = bestService.resourceBits;
                bits(:,m) = leo_resource_service(data,m,inner.x);
                trial = leo_service_totals(data,bits); blockwiseEvaluations = blockwiseEvaluations+1;
                if leo_service_is_better(trial,bestService,phase,s0)
                    trialX = bestX; trialX(:,m) = inner.x;
                    exact = problem.evaluate(trialX);
                    if leo_service_is_better(exact,bestService,phase,s0)
                        bestX = trialX; bestService = exact; blockwiseAccepted = blockwiseAccepted+1;
                        checkpoints=record_checkpoint(checkpoints,bestService,k,toc(budget.timer),m,'blockwise');
                    end
                end
            end
        end
        priceX(:,m) = inner.x;
        improvement = improvement+inner.score-inner.oldScore;
        solved = solved+1; steps = steps+inner.sbSteps; repairs = repairs+inner.nRepaired;
    end
    % 下面三者分别是价格反馈、原始评价、完整日程恢复，禁止互相替代。
    priceLower = leo_evaluate_quadratic_service(data,proxy.lower,priceX);
    priceService = problem.evaluate(priceX);
    if leo_service_is_better(priceService,bestService,phase,s0)
        bestX = priceX; bestService = priceService;
        checkpoints=record_checkpoint(checkpoints,bestService,k,toc(budget.timer),0,'price_schedule');
    end
    evaluations = 0; crossEvaluations = 0; acceptedMoves = 0;
    starts = {priceX,bestX};
    for r = 1:2
        if r==2 && isequal(starts{1},starts{2}), continue; end
        if leo_budget_expired(budget), break; end
        recovered = leo_recover_schedule(problem,starts{r},phase,s0,options,k,budget);
        evaluations = evaluations+recovered.evaluations;
        crossEvaluations = crossEvaluations+recovered.crossEvaluations;
        acceptedMoves = acceptedMoves+recovered.acceptedMoves;
        if leo_service_is_better(recovered.service,bestService,phase,s0)
            bestX = recovered.x; bestService = recovered.service;
            checkpoints=record_checkpoint(checkpoints,bestService,k,toc(budget.timer),0,'recovery');
        end
    end
    if k>1
        upper = leo_original_upper_bound(data,cache,lambda,phase,s0);
        if upper.value<bestUpper.value, bestUpper = upper; end
    end
    step = initialStep/k^options.stepExponent;
    lambdaNext = leo_update_prices(lambda,priceLower.userBits,data.qosTargetBits,sAux,step);
    history.lambdaNext(:,k) = lambdaNext;
    history.lowerUserBits(:,k) = priceLower.userBits;
    history.priceX(:,:,k) = priceX;
    history.sAux(k) = sAux; history.step(k) = step;
    history.priceFairness(k) = priceService.fairness; history.priceTotalBits(k) = priceService.totalBits;
    history.savedFairness(k) = bestService.fairness; history.savedTotalBits(k) = bestService.totalBits;
    history.upperBound(k) = bestUpper.value; history.proxyEpoch(k) = epoch;
    history.innerImprovement(k) = improvement; history.resourcesSolved(k) = solved;
    history.sbSteps(k) = steps; history.repairedCandidates(k) = repairs;
    history.recoveryEvaluations(k) = evaluations; history.crossEvaluations(k) = crossEvaluations;
    history.acceptedMoves(k) = acceptedMoves; history.elapsedSeconds(k) = toc(budget.timer);
    history.blockwiseEvaluations(k) = blockwiseEvaluations; history.blockwiseAccepted(k) = blockwiseAccepted;
    history.completePriceRound(k) = solved==M;
    completed = k; lambda = lambdaNext;
    if options.verbose && (k==1 || mod(k,5)==0 || k==rounds)
        fprintf('  %-10s %3d: raw fairness=%.9g, total=%.6g Mbit, valid gap=%.6g\n', ...
            phase,k,bestService.fairness,bestService.totalBits/1e6, ...
            certified_gap(bestUpper.value,bestService,isFairness));
    end
    if options.refreshEvery>0 && mod(k,options.refreshEvery)==0 && k<rounds && ...
            ~leo_budget_expired(budget) && certified_gap(bestUpper.value,bestService,isFairness)>options.gapTolerance
        proxy = leo_build_service_surrogates(problem,'current_schedule',bestX);
        epoch = epoch+1;
        errors(epoch) = proxy.error.optimalFairnessGapBound; %#ok<AGROW>
        touchErrors(epoch) = proxy.referenceTouchMaxAbsBits; %#ok<AGROW>
    end
end
if certified_gap(bestUpper.value,bestService,isFairness)<=options.gapTolerance
    status = 'bound_gap';
elseif leo_budget_expired(budget)
    status = 'time_limit';
end
names = fieldnames(history);
for j = 1:numel(names)
    name = names{j};
    if strcmp(name,'priceX'), history.(name) = history.(name)(:,:,1:completed);
    else, history.(name) = history.(name)(:,1:completed); end
end
checkpoints=record_checkpoint(checkpoints,bestService,completed,toc(budget.timer),0,'end');
result.checkpoints=checkpoints;
result.x = bestX; result.service = bestService; result.fairnessFloor = s0;
result.rounds = completed; result.status = status; result.history = history;
result.upperBound = bestUpper;
result.absoluteGap = certified_gap(bestUpper.value,bestService,isFairness);
result.certifiedWithinTolerance = result.absoluteGap<=options.gapTolerance;
result.lambda = lambda; result.proxy = proxy;
result.proxyEpochFairnessErrorBounds = errors;
result.proxyEpochTouchErrorsBits = touchErrors;
result.elapsedAtEndSeconds = toc(budget.timer);
result.initialService = start.service; result.initialElapsedSeconds = initialSeconds;
result.initialUpperBound = initialUpper; result.iterationKind = 'price_round';
result.sbTrace = firstSbTrace;
end

function gap = certified_gap(upper,service,isFairness)
if isFairness, value = service.fairness; else, value = service.normalizedThroughput; end
assert(upper>=value-1e-10*max(1,abs(value)),'有效上界小于原始可行值，请检查模型/上界。');
gap = max(0,upper-value);           % 仅消除浮点量级负差距；不改动上界本身
end

function h=record_checkpoint(h,service,iteration,seconds,resource,kind)
empty=isempty(h);
h=leo_record_search_step(h,service,iteration,seconds,NaN);
if empty, h.resource=[]; h.kind={}; end
h.resource(end+1)=resource; h.kind{end+1}=kind;
end
