function result = leo_recover_schedule(problem,x,phase,s0,options,roundIndex,budget)
%LEO_RECOVER_SCHEDULE 12.2：整周期原始服务的有限 add/drop/replace/跨资源交换。
% 接口标注：
% 输入：problem/x：原模型与起点；phase/s0：验收规则；options/roundIndex/budget。
% 输出：result：原始服务严格改善的完整日程、服务及动作计数。
% 每次仅重算受影响资源；拟接受时调用完整原始评价器复核，避免累计舍入误差。
% 阶段 2 的起点若不满足门槛，不用它冒充可行恢复点；保留日程仍单独恢复。
if nargin<7, budget = []; end
data = problem.data; M = data.shape(2);
service = problem.evaluate(x); x = logical(x);
result.evaluations = 0; result.crossEvaluations = 0; result.acceptedMoves = 0;
if strcmp(phase,'throughput') && any(service.demandRatio<s0)
    result.x = x; result.service = service; return;
end
for pass = 1:options.recoveryPasses
    if result.evaluations>=options.recoveryEvaluations || leo_budget_expired(budget), break; end
    remainingPasses = options.recoveryPasses-pass+1;
    passBudget = ceil((options.recoveryEvaluations-result.evaluations)/remainingPasses);
    crossBudget = floor(passBudget*options.crossResourceFraction)*(M>1);
    localEnd = result.evaluations+passBudget-crossBudget;
    passEnd = result.evaluations+passBudget;
    bestX = x; bestService = service; improved = false;
    [~,userOrder] = sort(service.demandRatio,'ascend');
    resourceOrder = mod((0:M-1)+roundIndex+pass-2,M)+1;
    % 每轮旋转块的起点，避免动作预算总是耗在第一个块。
    for m = resourceOrder
        present = userOrder(x(userOrder,m));
        absent = userOrder(data.available(userOrder,m) & ~x(userOrder,m));
        % 优先给最缺服务者增加/替换，然后检查删除。
        for i = absent.'
            if result.evaluations>=localEnd || leo_budget_expired(budget), break; end
            group = x(:,m); group(i) = true;
            consider(m,group,false);
            for j = flipud(present).'
                if result.evaluations>=localEnd || leo_budget_expired(budget), break; end
                group = x(:,m); group(i) = true; group(j) = false;
                consider(m,group,false);
            end
        end
        for j = flipud(present).'
            if result.evaluations>=localEnd || leo_budget_expired(budget), break; end
            group = x(:,m); group(j) = false;
            consider(m,group,false);
        end
        if result.evaluations>=localEnd || leo_budget_expired(budget), break; end
    end
    % 交换两个块中不同的用户：各块人数不变，但所有干扰/累计服务重新评价。
    for a = 1:(M-1)*(crossBudget>0)
        m = resourceOrder(a);
        for b = a+1:M
            n = resourceOrder(b);
            left = userOrder(x(userOrder,m) & ~x(userOrder,n) & data.available(userOrder,n));
            right = userOrder(x(userOrder,n) & ~x(userOrder,m) & data.available(userOrder,m));
            for i = left.'
                for j = right.'
                    if result.evaluations>=passEnd || leo_budget_expired(budget), break; end
                    groups = x(:,[m,n]);
                    groups(i,:) = [false,true]; groups(j,:) = [true,false];
                    consider([m,n],groups,true);
                end
                if result.evaluations>=passEnd || leo_budget_expired(budget), break; end
            end
            if result.evaluations>=passEnd || leo_budget_expired(budget), break; end
        end
        if result.evaluations>=passEnd || leo_budget_expired(budget), break; end
    end
    if improved
        x = bestX; service = bestService; result.acceptedMoves = result.acceptedMoves+1;
    end
    % 下一遍旋转资源；即使此遍未改善，也可能有尚未检查的资源。
end
result.x = x; result.service = service;

    function consider(columns,groups,isCross)
        % 不合法动作不进入昂贵服务评价，也不会传入原始模型。
        for c = 1:numel(columns)
            ids = find(groups(:,c));
            if numel(ids)>data.maxStreams || any(~data.available(ids,columns(c))) || ...
                    numel(unique(data.beamIndex(ids,columns(c))))<numel(ids)
                return;
            end
        end
        result.evaluations = result.evaluations+1;
        result.crossEvaluations = result.crossEvaluations+isCross;
        resourceBits = service.resourceBits;
        for c = 1:numel(columns)
            resourceBits(:,columns(c)) = leo_resource_service(data,columns(c),groups(:,c));
        end
        trial.userBits = sum(resourceBits,2);
        trial.demandRatio = trial.userBits./data.qosTargetBits;
        trial.fairness = min(1,min(trial.demandRatio)); trial.totalBits = sum(trial.userBits);
        if ~leo_service_is_better(trial,bestService,phase,s0), return; end
        trialX = x; trialX(:,columns) = groups;
        trial = problem.evaluate(trialX);
        if leo_service_is_better(trial,bestService,phase,s0)
            bestX = trialX; bestService = trial; improved = true;
        end
    end
end
