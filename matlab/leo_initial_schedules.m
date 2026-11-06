function initial = leo_initial_schedules(problem,provided,options,budget)
%LEO_INITIAL_SCHEDULES 空/预检见证/用户提供/需求轮转/随机可行起点；不读取穷举。
% 接口标注：
% 输入：problem：原模型；provided：可选已有日程；options/budget：随机种子及预算。
% 输出：initial：共同可行初始化中按原始公平/吞吐最好的日程与各起点成绩。
if nargin<4, budget = []; end
data = problem.data; K = data.shape(1); M = data.shape(2);
schedules = {false(data.shape),logical(problem.precheck.witness)};
names = {'empty','flow_witness'};
if ~isempty(provided)
    problem.evaluate(provided); % 先校验，禁止静默修正输入的非法日程
    schedules{end+1} = logical(provided); names{end+1} = 'provided';
end
% 按累计需求满足率从低到高轮转；每个块保持同一用户组。
x = false(data.shape); cumulative = zeros(K,1);
for m = 1:M
    [~,order] = sort(cumulative./data.qosTargetBits,'ascend');
    usedBeams = [];
    for i = order.'
        if ~data.available(i,m) || any(usedBeams==data.beamIndex(i,m)), continue; end
        x(i,m) = true; usedBeams(end+1) = data.beamIndex(i,m); %#ok<AGROW>
        if sum(x(:,m))==data.maxStreams, break; end
    end
    cumulative = cumulative+leo_resource_group_services(data,m,x(:,m));
end
schedules{end+1} = x; names{end+1} = 'demand_rotation';
for r = 1:options.randomInitialSchedules
    if leo_budget_expired(budget), break; end
    x = false(data.shape);
    for m = 1:M
        ids = find(data.available(:,m)); ids = ids(randperm(numel(ids)));
        usedBeams = [];
        for i = ids.'
            if any(usedBeams==data.beamIndex(i,m)), continue; end
            x(i,m) = true; usedBeams(end+1) = data.beamIndex(i,m); %#ok<AGROW>
            if sum(x(:,m))==data.maxStreams, break; end
        end
    end
    schedules{end+1} = x; names{end+1} = sprintf('random_%d',r);
end
initial.names = names;
initial.fairness = zeros(1,numel(schedules)); initial.totalBits = initial.fairness;
initial.x = schedules{1}; initial.service = problem.evaluate(initial.x); initial.bestName = names{1};
for r = 1:numel(schedules)
    service = problem.evaluate(schedules{r});
    initial.fairness(r) = service.fairness; initial.totalBits(r) = service.totalBits;
    if leo_service_is_better(service,initial.service,'fairness',0)
        initial.x = schedules{r}; initial.service = service; initial.bestName = names{r};
    end
end
initial.usesExhaustiveSolution = false;
end
