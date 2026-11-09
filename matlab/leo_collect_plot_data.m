function data = leo_collect_plot_data(report)
%LEO_COLLECT_PLOT_DATA 整理同口径绘图数据；不运行优化、不补造缺失迭代。
% 输入：leo_benchmark_case/run_leo_benchmarks 的报告（兼容旧版无日志报告）。
% 输出：记录、分口径计数、全过程、代表种子日程及固定代理诊断数值。
data.schemaVersion = 1; data.caseName = 'custom';
data.serviceModel = 'slot_union';
if isfield(report.problemData.design,'serviceModel'), data.serviceModel = report.problemData.design.serviceModel; end
if isfield(report,'caseName'), data.caseName = report.caseName; end
data.methods = report.options.methods; data.seeds = report.options.seeds;
data.representativeSeed = data.seeds(1); data.budgetSeconds = report.options.budgetSeconds;
data.records = report.records; data.summary = report.summary;
data.shape = report.problemData.shape; data.maxStreams = report.problemData.maxStreams;
data.nBeams = size(report.problemData.design.beamPowerW,2);
data.targetBits = report.problemData.qosTargetBits;
data.referenceBits = report.problemData.referenceBits;
data.available = report.problemData.available;
data.beamIndex = report.problemData.beamIndex;
data.reference = report.exhaustive;
data.counts = struct([]); data.events = struct([]); data.prices = struct([]);
data.energy = struct([]); data.progress = struct([]); data.representatives = struct([]);
for r = 1:numel(report.records)
    row = report.records(r); count = empty_count(row);
    if ~strcmp(row.status,'completed')
        if isempty(data.counts), data.counts = count; else, data.counts(end+1,1) = orderfields(count,data.counts); end; continue; %#ok<AGROW>
    end
    result = report.solutions{r}; offset = row.commonSeconds+row.proxyPreparationSeconds;
    initialTime = known_initial_time(result);
    if strcmp(row.method,'sb_reference_portfolio') && ~isfield(result,'memberRuns'), initialTime = NaN; end
    if isfinite(initialTime)
        data.progress = progress_point(data.progress,row,offset+initialTime,result.initial.service,'initial');
    end
    if strcmp(row.method,'sb_reference_portfolio')
        % 组合方法必须累计所有分支工作量，不能只统计最后胜出的分支。
        if isfield(result,'memberRuns')
            count.portfolioMembers = numel(result.memberRuns);
            for b = 1:numel(result.memberRuns)
                member = result.memberRuns{b};
                [data,count] = collect_stages(data,count,row,member,offset+member.offsetSeconds, ...
                    member.name,report.options.method.sbTrajectories,false);
            end
        end
        if isfield(result,'portfolioHistory') && ~isempty(result.portfolioHistory)
            h = result.portfolioHistory;
            for k = 1:numel(h.iteration)
                service.fairness = h.savedFairness(k); service.totalBits = h.savedTotalBits(k);
                data.progress = progress_point(data.progress,row,offset+h.elapsedSeconds(k),service,'member_completed');
            end
        end
    else
        [data,count] = collect_stages(data,count,row,result,offset,'main', ...
            report.options.method.sbTrajectories,true);
    end
    if isfield(result,'evaluations'), count.originalEvaluations = result.evaluations; end
    if isempty(data.counts), data.counts = count; else, data.counts(end+1,1) = orderfields(count,data.counts); end
    data.progress = progress_point(data.progress,row,row.endToEndSeconds,result.service,'final');
    if row.seed==data.representativeSeed
        rep.method = row.method; rep.seed = row.seed; rep.x = result.x;
        rep.service = leo_evaluate_service(report.problemData,result.x);
        rep.initial = result.initial.service; rep.stage1 = result.stage1.service;
        rep.fairnessFloor = result.fairnessFloor;
        if isempty(data.representatives), data.representatives = rep; else, data.representatives(end+1,1) = orderfields(rep,data.representatives); end
    end
end
% 诊断图一律在计时实验结束后计算；使用同一个固定 minimax 代理。
problem.data = report.problemData;
proxy = leo_build_service_surrogates(problem,'minimax');
data.approximation = struct();
event = find(proxy.limits.eventMask & proxy.limits.maxW>0,1);
if ~isempty(event)
    [i,t] = ind2sub(size(proxy.limits.maxW),event);
    I = linspace(0,proxy.limits.maxW(i,t),201);
    S = problem.data.design.signalW(i,t); N = problem.data.design.noiseW(i,t);
    a.user = i; a.slot = t; a.normalizedInterference = I/proxy.limits.maxW(i,t);
    a.reference = proxy.referenceW(i,t)/proxy.limits.maxW(i,t);
    a.originalMbps = leo_rate_and_derivatives(S,N,problem.data.bandwidthHz,I)/1e6;
    a.lowerMbps = (proxy.tangent.alphaBps(i,t)-proxy.tangent.omegaBpsPerW(i,t)*I)/1e6;
    a.upperMbps = (proxy.chord.alphaBps(i,t)-proxy.chord.omegaBpsPerW(i,t)*I)/1e6;
    data.approximation = a;
end
data.serviceBounds = struct([]);
for r = 1:numel(data.representatives)
    rep = data.representatives(r);
    low = leo_evaluate_quadratic_service(problem.data,proxy.lower,rep.x);
    high = leo_evaluate_quadratic_service(problem.data,proxy.upper,rep.x);
    bound.method = rep.method; bound.lowerBits = low.userBits;
    bound.originalBits = rep.service.userBits; bound.upperBits = high.userBits;
    if strcmp(data.serviceModel,'periodic_chernoff')
        bound.lowerBits = max(0,bound.lowerBits); bound.upperBits = max(0,bound.upperBits);
    end
    bound.lowerErrorBoundBits = proxy.error.lowerUserBits;
    if isempty(data.serviceBounds), data.serviceBounds = bound; else, data.serviceBounds(end+1,1) = orderfields(bound,data.serviceBounds); end
end
data.notes = {'Counter NaN means not applicable or not reported, never zero iterations.', ...
    'Iteration units differ by algorithm; price rounds, native search steps and SB integration steps are separate.', ...
    'Representative curves use the first requested seed, not the best run.', ...
    'SB energy is the best-so-far discrete energy of one fixed Ising call before repair.', ...
    'Service/SINR figures use the statistical-CSI design coefficients, not instantaneous fading.', ...
    'Postprocessing and plotting time is excluded from measured algorithm time.'};
if strcmp(data.serviceModel,'periodic_chernoff')
    data.notes{end+1} = 'Totals and QoS use period guaranteed service G; resource bars use additive A before the one-time risk margin. Nominal throughput is separate.';
end
end

function c = empty_count(row)
c.method = row.method; c.seed = row.seed; c.status = row.status;
fields = {'priceRounds1','priceRounds2','completeRounds1','completeRounds2', ...
    'searchSteps1','searchSteps2','nodes1','nodes2','milpCalls', ...
    'sbIntegrationSteps','sbTrajectorySteps','resourceSolves','repairedCandidates', ...
    'recoveryEvaluations','crossEvaluations','acceptedMoves','proxyRefreshes', ...
    'blockwiseEvaluations','blockwiseAccepted', ...
    'originalEvaluations','portfolioMembers'};
for j = 1:numel(fields), c.(fields{j}) = NaN; end
c.searchKind = '';
end

function [data,c] = collect_stages(data,c,row,result,offset,member,trajectories,addProgress)
for phase = 1:2
    stage = result.(sprintf('stage%d',phase)); suffix = num2str(phase);
    if isfield(stage,'rounds')
        c = increment(c,['priceRounds',suffix],stage.rounds);
        h = stage.history;
        c = increment(c,['completeRounds',suffix],sum(h.completePriceRound));
        c = increment(c,'resourceSolves',sum(h.resourcesSolved));
        c = increment(c,'sbIntegrationSteps',sum(h.sbSteps));
        c = increment(c,'sbTrajectorySteps',sum(h.sbSteps)*trajectories);
        pairs = {'repairedCandidates','repairedCandidates';'recoveryEvaluations','recoveryEvaluations'; ...
            'crossEvaluations','crossEvaluations';'acceptedMoves','acceptedMoves'};
        for j = 1:size(pairs,1), c = increment(c,pairs{j,1},sum(h.(pairs{j,2}))); end
        if isfield(h,'blockwiseEvaluations'), c = increment(c,'blockwiseEvaluations',sum(h.blockwiseEvaluations)); end
        if isfield(h,'blockwiseAccepted'), c = increment(c,'blockwiseAccepted',sum(h.blockwiseAccepted)); end
        if isfield(stage,'proxyEpochFairnessErrorBounds')
            c = increment(c,'proxyRefreshes',numel(stage.proxyEpochFairnessErrorBounds)-1);
        end
    elseif isfield(stage,'iterations')
        if strcmp(stage.iterationKind,'branch_and_bound_nodes')
            c = increment(c,['nodes',suffix],stage.iterations);
        else
            c = increment(c,['searchSteps',suffix],stage.iterations);
            c.searchKind = stage.iterationKind;
        end
    end
    if isfield(stage,'solver') && isfield(stage.solver,'called')
        c = increment(c,'milpCalls',double(stage.solver.called));
    end
    if isfield(stage,'history')
        h = stage.history;
        if isfield(stage,'initialUpperBound') && isfield(stage,'initialElapsedSeconds')
            e.method = row.method; e.seed = row.seed; e.member = member; e.phase = phase;
            e.iteration = 0; e.elapsedSeconds = offset+stage.initialElapsedSeconds;
            e.fairness = stage.initialService.fairness; e.totalBits = stage.initialService.totalBits;
            e.upperBound = stage.initialUpperBound;
            if phase==2, e.upperBound = e.upperBound*data.referenceBits; end
            e.priceFairness = NaN; e.priceTotalBits = NaN;
            e.completePriceRound = NaN; e.proxyEpoch = NaN;
            if isempty(data.events), data.events = e; else, data.events(end+1,1) = orderfields(e,data.events); end
            if addProgress
                data.progress = progress_point(data.progress,row,e.elapsedSeconds,stage.initialService, ...
                    sprintf('phase%d_initial',phase));
            end
        end
        for k = 1:numel(h.elapsedSeconds)
            e.method = row.method; e.seed = row.seed; e.member = member; e.phase = phase;
            if isfield(h,'iteration'), e.iteration = h.iteration(k); else, e.iteration = k; end
            e.elapsedSeconds = offset+h.elapsedSeconds(k);
            e.fairness = h.savedFairness(k); e.totalBits = h.savedTotalBits(k);
            e.upperBound = NaN; e.priceFairness = NaN; e.priceTotalBits = NaN;
            e.completePriceRound = NaN; e.proxyEpoch = NaN;
            if isfield(h,'upperBound')
                e.upperBound = h.upperBound(k);
                if phase==2, e.upperBound = e.upperBound*data.referenceBits; end
                e.priceFairness = h.priceFairness(k); e.priceTotalBits = h.priceTotalBits(k);
                e.completePriceRound = double(h.completePriceRound(k)); e.proxyEpoch = h.proxyEpoch(k);
            end
            if isempty(data.events), data.events = e; else, data.events(end+1,1) = orderfields(e,data.events); end
            if addProgress
                service.fairness = e.fairness; service.totalBits = e.totalBits;
                data.progress = progress_point(data.progress,row,e.elapsedSeconds,service,sprintf('phase%d',phase));
            end
            if isfield(h,'lambda')
                for i = 1:size(h.lambda,1)
                    p.method = row.method; p.seed = row.seed; p.member = member;
                    p.phase = phase; p.iteration = e.iteration; p.user = i;
                    p.lambda = h.lambda(i,k); p.lambdaNext = h.lambdaNext(i,k);
                    p.lowerDemandRatio = h.lowerUserBits(i,k)/data.targetBits(i);
                    p.targetRatio = h.sAux(k); p.step = h.step(k);
                    if isempty(data.prices), data.prices = p; else, data.prices(end+1,1) = orderfields(p,data.prices); end
                end
            end
        end
    end
    if isfield(stage,'sbTrace') && ~isempty(stage.sbTrace)
        trace = stage.sbTrace; h = trace.history;
        for k = 1:numel(h.step)
            energy.method = row.method; energy.seed = row.seed; energy.member = member;
            energy.phase = phase; energy.resource = trace.resource; energy.priceIteration = trace.priceIteration;
            energy.step = h.step(k); energy.minimum = h.minimum(k);
            energy.median = h.median(k); energy.maximum = h.maximum(k);
            energy.trajectories = trace.trajectories; energy.energyScale = trace.energyScale;
            if isempty(data.energy), data.energy = energy; else, data.energy(end+1,1) = orderfields(energy,data.energy); end
        end
    end
    if addProgress && isfield(stage,'elapsedAtEndSeconds')
        data.progress = progress_point(data.progress,row,offset+stage.elapsedAtEndSeconds, ...
            stage.service,sprintf('phase%d_end',phase));
    end
end
end

function c = increment(c,name,value)
if ~isfinite(value), return; end
if isnan(c.(name)), c.(name) = 0; end
c.(name) = c.(name)+value;
end

function rows = progress_point(rows,row,time,service,kind)
p.method = row.method; p.seed = row.seed; p.seconds = time;
p.fairness = service.fairness; p.totalBits = service.totalBits; p.kind = kind;
if isempty(rows), rows = p; else, rows(end+1,1) = orderfields(p,rows); end
end

function seconds = known_initial_time(result)
% 不把需要计算的共同初始解画在 t=0。旧版缺少时间戳时省略该点。
seconds = NaN;
if isfield(result,'memberRuns') && ~isempty(result.memberRuns)
    member = result.memberRuns{1};
    if isfield(member.stage1,'initialElapsedSeconds')
        seconds = member.offsetSeconds+member.stage1.initialElapsedSeconds;
    end
elseif isfield(result,'initializationSeconds')
    seconds = result.initializationSeconds;
elseif isfield(result.stage1,'history')
    h = result.stage1.history;
    if isfield(h,'iteration') && ~isempty(h.iteration) && h.iteration(1)==0
        seconds = h.elapsedSeconds(1);
    end
end
end
