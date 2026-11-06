function groups = leo_enumerate_resource_groups(data,m,maxGroups)
%LEO_ENUMERATE_RESOURCE_GROUPS 列出所有合法二元组，第一列是空组。
% 接口标注：
% 输入：data：模型；m：块号；maxGroups：合法组数量保护阈值。
% 输出：groups：K×G 合法二元组，包括空组。
% 每波束选“不激活”或“恰好一位用户”，同时限制总人数；没有候选筛选。
estimate = leo_exhaustive_size(data);
assert(estimate.groupsPerResource(m)<=maxGroups,'单资源合法组数超限。');
K = data.shape(1);
groups = false(K,1);
sizes = 0;
codes = unique(data.beamIndex(data.available(:,m),m));
for code = codes.'
    users = find(data.available(:,m) & data.beamIndex(:,m)==code);
    extend = find(sizes<data.maxStreams);
    n = numel(extend);
    additional = repmat(groups(:,extend),1,numel(users));
    for j = 1:numel(users)
        additional(users(j),(j-1)*n+(1:n)) = true;
    end
    groups = [groups,additional]; %#ok<AGROW>
    sizes = [sizes,repmat(sizes(extend)+1,1,numel(users))]; %#ok<AGROW>
end
assert(size(groups,2)==estimate.groupsPerResource(m));
end
