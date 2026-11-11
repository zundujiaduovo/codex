function result = leo_original_greedy(problem,start,phase,s0,budget,stopContext)
%LEO_ORIGINAL_GREEDY 第 13.3 节：需求缺口优先，按原始服务选择最佳可加块。
% 输入：原问题、起点、阶段/门槛、时间预算；输出保存的完整日程与评价次数。
data = problem.data; x = start.x; service = start.service; evaluations = 0;
if nargin<6, stopContext=[]; end
stopStatus='';
iteration = 0; history = leo_record_search_step([],service,0,toc(budget.timer),0);
while ~leo_budget_expired(budget)
    [~,order] = sort(service.demandRatio,'ascend'); found = false;
    for i = order.'
        candidateFound = false; candidate = service; candidateX = x;
        for m = find(data.available(i,:) & ~x(i,:))
            if leo_budget_expired(budget), break; end
            group = x(:,m); group(i) = true; ids = find(group);
            if numel(ids)>data.maxStreams || numel(unique(data.beamIndex(ids,m)))<numel(ids), continue; end
            bits = service.resourceBits; bits(:,m) = leo_resource_service(data,m,group);
            trial = leo_service_totals(data,bits);
            evaluations = evaluations+1;
            if leo_service_is_better(trial,candidate,phase,s0)
                candidate = trial; candidateX = x; candidateX(:,m) = group; candidateFound = true;
            end
        end
        if candidateFound
            exact = problem.evaluate(candidateX);
            if leo_service_is_better(exact,service,phase,s0)
                x = candidateX; service = exact; found = true;
                iteration = iteration+1;
                history = leo_record_search_step(history,service,iteration,toc(budget.timer),evaluations);
                if ~isempty(stopContext)
                    known=stopContext.incumbent;
                    if leo_service_is_better(service,known,phase,s0), known=service; end
                    [~,reason]=leo_search_stopping(stopContext.options,phase,known, ...
                        stopContext.upper,toc(budget.timer),0);
                    if strcmp(reason,'target_gap'), stopStatus=reason; end
                end
                break;
            end
        end
    end
    if ~found || ~isempty(stopStatus), break; end
end
result.x = x; result.service = service; result.evaluations = evaluations;
result.history = history; result.iterations = iteration; result.iterationKind = 'accepted_addition';
result.stopStatus=stopStatus;
end
