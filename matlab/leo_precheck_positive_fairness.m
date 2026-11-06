function check = leo_precheck_positive_fairness(data)
%LEO_PRECHECK_POSITIVE_FAIRNESS O2/6.4：最大流检查每用户至少一次正服务。
% 接口标注：
% 输入：data：所有用户需求、正服务机会与硬约束。
% 输出：check：最大流值、见证日程、正公平可能性与不可服务用户。
% 无工具箱 Edmonds-Karp；仅判断正公平可服务性，不求 QoS 最优调度。
% 源->用户(1)->资源/码字(1)->资源(1)->汇(L)。不代表需求完全达标。
K = data.shape(1); M = data.shape(2);
eligible = false(K,M);
for m = 1:M
    slots = find(data.slotToResource==m & data.dataDurationS>0);
    eligible(:,m) = data.available(:,m) & any(data.design.signalW(:,slots)>0,2);
end
source = 1;
userNode = (2:K+1).';
groupNode = zeros(K,M);
nodeCount = K+1;
groupIds = []; groupResources = [];
for m = 1:M
    codes = unique(data.beamIndex(eligible(:,m),m));
    for code = codes.'
        nodeCount = nodeCount+1;
        groupNode(eligible(:,m) & data.beamIndex(:,m)==code,m) = nodeCount;
        groupIds(end+1,1) = nodeCount; %#ok<AGROW>
        groupResources(end+1,1) = m; %#ok<AGROW>
    end
end
resourceNodes = nodeCount+(1:M);
sink = nodeCount+M+1;
from = repmat(source,K,1); to = userNode; capacity = ones(K,1);
for m = 1:M
    users = find(eligible(:,m));
    from = [from;userNode(users)]; %#ok<AGROW>
    to = [to;groupNode(users,m)]; %#ok<AGROW>
    capacity = [capacity;ones(numel(users),1)]; %#ok<AGROW>
end
from = [from;groupIds;resourceNodes(:)];
to = [to;reshape(resourceNodes(groupResources),[],1);repmat(sink,M,1)];
capacity = [capacity;ones(numel(groupIds),1);repmat(data.maxStreams,M,1)];
residual = sparse(from,to,capacity,sink,sink);
flow = 0;
while flow<K
    parent = zeros(sink,1); parent(source) = -1;
    queue = zeros(sink,1); queue(1) = source; head = 1; tail = 1;
    while head<=tail && parent(sink)==0
        node = queue(head); head = head+1;
        next = find(residual(node,:)>0);
        for neighbor = next
            if parent(neighbor)~=0, continue; end
            parent(neighbor) = node;
            tail = tail+1; queue(tail) = neighbor;
            if neighbor==sink, break; end
        end
    end
    if parent(sink)==0, break; end
    node = sink;
    while node~=source
        prev = parent(node);
        residual(prev,node) = residual(prev,node)-1;
        residual(node,prev) = residual(node,prev)+1;
        node = prev;
    end
    flow = flow+1; % 源到用户容量为 1，每次增广恰好 1
end
check.witness = false(K,M);
for m = 1:M
    for i = find(eligible(:,m)).'
        check.witness(i,m) = residual(userNode(i),groupNode(i,m))==0;
    end
end
check.maxFlow = flow;
check.userCount = K;
check.simpleCapacityNecessary = K<=data.maxStreams*M;
check.neverServiceableUsers = find(~any(eligible,2));
check.unmatchedUsersInWitness = find(~any(check.witness,2));
check.canHavePositiveFairness = flow==K;
check.forcedZeroFairness = flow<K;
check.witnessService = leo_evaluate_service(data,check.witness);
if check.canHavePositiveFairness
    assert(check.witnessService.fairness>0,'理论正服务在数值计算中下溢。');
end
check.scope = 'Baseline O2 only: positive fairness, not all demand targets satisfied.';
end
