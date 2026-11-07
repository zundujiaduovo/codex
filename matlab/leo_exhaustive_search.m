function result = leo_exhaustive_search(problem,overrides)
%LEO_EXHAUSTIVE_SEARCH 完整日程穷举，原始 O2/O4 字典序全局对照。
% 接口标注：
% 输入：problem：原问题；overrides：可选穷举预算。
% 输出：result：最优/超限/超时状态、已访问数量、最好合法日程及原始服务。
% 对所有资源合法组的笛卡尔积逐一评价；无剪枝、采样或逐块贪心。
% 先比较 min(1,min(D_i/q_i))，严格同分再比较总服务；不放宽公平门槛。
if nargin<2, overrides = struct(); end
options = leo_exhaustive_options(overrides);
data = problem.data;
started = tic;
estimate = leo_exhaustive_size(data);
K = data.shape(1); M = data.shape(2);
% 预估包括生成组的临时复制与批次矩阵，不是运行器的精确峰值内存测量。
cacheBytes = 2*9*K*sum(estimate.groupsPerResource)+8*K*K;
batchBytes = 8*(4*K+2*M+16)*options.batchSize;
result.status = 'not_started';
result.completed = false;
result.optimal = false;
result.hasIncumbent = false;
result.x = [];
result.fairness = NaN;
result.totalBits = NaN;
result.normalizedThroughput = NaN;
result.service = [];
result.estimate = estimate;
result.estimatedMemoryBytes = cacheBytes+batchBytes;
result.visitedSchedules = 0;
result.options = options;
result.stage1Complete = false;
result.stage2Complete = false;
result.cacheSeconds = 0;
result.enumerationSeconds = 0;
result.elapsedSeconds = 0;
result.comparisonRule = 'Strict lexicographic comparison in double precision; no fairness tolerance.';
result.reason = '';
if options.verbose
    fprintf('Exhaustive: %d resources, %.6g schedules (log10=%.4f).\n', ...
        M,estimate.totalSchedules,estimate.log10Schedules);
end
if estimate.totalSchedules>options.maxSchedules || ...
        any(estimate.groupsPerResource>options.maxGroupsPerResource) || ...
        result.estimatedMemoryBytes>options.maxMemoryBytes
    result.status = 'size_limit';
    result.reason = 'Complete search exceeds configured schedule, group, or memory limits; no search performed.';
    result.elapsedSeconds = toc(started);
    if options.verbose, fprintf('%s\n',result.reason); end
    return;
end
assert(estimate.countExactInDouble,'当前计数无法精确表示，不能穷举索引。');
groups = cell(1,M); services = cell(1,M);
for m = 1:M
    if toc(started)>=options.maxSeconds
        result.status = 'time_limit';
        result.reason = 'Time limit reached during group-service preparation; no complete schedule evaluated.';
        result.elapsedSeconds = toc(started);
        return;
    end
    groups{m} = leo_enumerate_resource_groups(data,m,options.maxGroupsPerResource);
    services{m} = leo_resource_group_services(data,m,groups{m});
end
result.cacheSeconds = toc(started);
enumerationStarted = tic;
bestFairness = -Inf; bestTotal = -Inf; bestChoice = [];
G = estimate.groupsPerResource;
N = estimate.totalSchedules;
for first = 0:options.batchSize:N-1
    if toc(started)>=options.maxSeconds, break; end
    last = min(first+options.batchSize-1,N-1);
    quotient = first:last;
    choices = zeros(M,numel(quotient));
    D = zeros(K,numel(quotient));
    for m = 1:M
        choices(m,:) = mod(quotient,G(m))+1;
        quotient = floor(quotient/G(m));
        D = D+services{m}(:,choices(m,:));
    end
    [~,margin] = leo_service_adjustment(data);
    D = max(0,bsxfun(@minus,D,margin));
    fairness = min(1,min(bsxfun(@rdivide,D,data.qosTargetBits),[],1));
    total = sum(D,1);
    batchBest = max(fairness);
    if batchBest>=bestFairness
        tied = find(fairness==batchBest);
        [batchTotal,index] = max(total(tied));
        if batchBest>bestFairness || batchTotal>bestTotal
            bestFairness = batchBest;
            bestTotal = batchTotal;
            bestChoice = choices(:,tied(index));
        end
    end
    result.visitedSchedules = last+1;
end
result.enumerationSeconds = toc(enumerationStarted);
result.completed = result.visitedSchedules==N;
result.optimal = result.completed;
result.stage1Complete = result.completed;
result.stage2Complete = result.completed;
if ~isempty(bestChoice)
    result.hasIncumbent = true;
    result.x = false(K,M);
    for m = 1:M, result.x(:,m) = groups{m}(:,bestChoice(m)); end
    % 独立用原始全日程评价器复核缓存结果，不能只相信缓存搜索输出。
    result.service = problem.evaluate(result.x);
    assert(abs(result.service.fairness-bestFairness)<=1e-10*max(1,bestFairness));
    assert(abs(result.service.totalBits-bestTotal)<=1e-10*max(1,bestTotal));
    result.fairness = result.service.fairness;
    result.totalBits = result.service.totalBits;
    result.normalizedThroughput = result.service.normalizedThroughput;
    result.cachedFairness = bestFairness;
    result.cachedTotalBits = bestTotal;
    result.groupChoice = bestChoice;
    point = [double(result.x(:));result.fairness];
    report = leo_check_problem_point(problem.stage1,point,problem.feasibilityTolerance);
    assert(report.feasible,'原始 O2 约束复核失败。');
    stage2 = problem.makeStage2(result.x);
    report = leo_check_problem_point(stage2,double(result.x(:)),problem.feasibilityTolerance);
    assert(report.feasible,'原始 O4 约束复核失败。');
end
if result.completed
    result.status = 'optimal';
    result.reason = 'Every feasible full schedule evaluated; lexicographic optimum in double precision.';
else
    result.status = 'time_limit';
    result.reason = 'Incomplete enumeration; any incumbent is feasible but not certified optimal.';
end
result.elapsedSeconds = toc(started);
if options.verbose
    fprintf('Exhaustive %s: visited %.0f/%.0f, time %.3f s, fairness %.9g, total %.6g bit.\n', ...
        result.status,result.visitedSchedules,N,result.elapsedSeconds,result.fairness,result.totalBits);
end
end
