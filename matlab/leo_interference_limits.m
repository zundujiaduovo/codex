function limits = leo_interference_limits(data)
%LEO_INTERFERENCE_LIMITS T2-T3：条件 x_i=1 下，其他不同波束中最大的 L-1 项。
% 接口标注：
% 输入：data：完整物理候选域及每流固定功率。
% 输出：limits：条件选中用户的 K×T 合法干扰上限 W 与事件掩码。
% 同波束不同候选用户的固定系数相同，只计一个波束；排除用户自己的波束。
K = data.shape(1); T = numel(data.slotToResource);
limits.maxW = zeros(K,T);
limits.eventMask = false(K,T);
for t = 1:T
    if data.dataDurationS(t)<=0, continue; end
    m = data.slotToResource(t);
    users = find(data.available(:,m));
    codes = unique(data.beamIndex(users,m));
    limits.eventMask(users,t) = true;
    for i = users.'
        others = codes(codes~=data.beamIndex(i,m));
        power = sort(reshape(data.design.beamPowerW(i,others,t),[],1),'descend');
        count = min(data.maxStreams-1,numel(power));
        limits.maxW(i,t) = sum(power(1:count));
    end
end
limits.scope = 'Conditional on x_i=1 and feasible binary hard constraints.';
end
