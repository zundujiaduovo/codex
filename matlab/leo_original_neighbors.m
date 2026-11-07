function neighbors = leo_original_neighbors(problem,x,service,maxEvaluations,roundIndex,budget)
%LEO_ORIGINAL_NEIGHBORS 第 13.3 节：生成原目标可行增删/替换及跨块交换邻域。
% 输入：完整可行日程及缓存服务、评价/时间预算；输出候选及其原始累计服务。
% 只重算受影响块内至多 L 位用户，价格代理不参与计分。
data = problem.data; M = data.shape(2); neighbors = struct('x',{},'service',{},'changed',{});
[~,users] = sort(service.demandRatio,'ascend');
order = mod((0:M-1)+roundIndex-1,M)+1;
localLimit = floor(.75*maxEvaluations); if M==1, localLimit = maxEvaluations; end
for m = order
    selected = users(x(users,m)); absent = users(data.available(users,m) & ~x(users,m));
    for i = absent.'
        group = x(:,m); group(i) = true; consider(m,group);
        for j = flipud(selected).'
            if numel(neighbors)>=localLimit || leo_budget_expired(budget), break; end
            group = x(:,m); group(i) = true; group(j) = false; consider(m,group);
        end
        if numel(neighbors)>=localLimit || leo_budget_expired(budget), break; end
    end
    for j = flipud(selected).'
        if numel(neighbors)>=localLimit || leo_budget_expired(budget), break; end
        group = x(:,m); group(j) = false; consider(m,group);
    end
    if numel(neighbors)>=localLimit || leo_budget_expired(budget), break; end
end
for a = 1:M-1
    m = order(a);
    for b = a+1:M
        n = order(b);
        left = users(x(users,m) & ~x(users,n) & data.available(users,n));
        right = users(x(users,n) & ~x(users,m) & data.available(users,m));
        for i = left.'
            for j = right.'
                if numel(neighbors)>=maxEvaluations || leo_budget_expired(budget), break; end
                groups = x(:,[m,n]); groups(i,:) = [false,true]; groups(j,:) = [true,false];
                consider([m,n],groups);
            end
            if numel(neighbors)>=maxEvaluations || leo_budget_expired(budget), break; end
        end
        if numel(neighbors)>=maxEvaluations || leo_budget_expired(budget), break; end
    end
    if numel(neighbors)>=maxEvaluations || leo_budget_expired(budget), break; end
end
    function consider(columns,groups)
        if numel(neighbors)>=maxEvaluations || leo_budget_expired(budget), return; end
        for c = 1:numel(columns)
            ids = find(groups(:,c));
            if numel(ids)>data.maxStreams || any(~data.available(ids,columns(c))) || ...
                    numel(unique(data.beamIndex(ids,columns(c))))<numel(ids), return; end
        end
        bits = service.resourceBits;
        for c = 1:numel(columns), bits(:,columns(c)) = leo_resource_service(data,columns(c),groups(:,c)); end
        trial = leo_service_totals(data,bits);
        next = x; next(:,columns) = groups;
        neighbors(end+1) = struct('x',next,'service',trial,'changed',find(next~=x));
    end
end
