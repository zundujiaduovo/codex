function better = leo_service_is_better(candidate,incumbent,phase,s0)
%LEO_SERVICE_IS_BETTER 原始设计服务验收；阶段 2 不容忍降低固定公平门槛。
% 接口标注：
% 输入：candidate/incumbent：原始服务；phase：fairness/throughput；s0：固定门槛。
% 输出：better：是否可替换保存日程；阶段 2 严格满足每用户门槛。
if strcmp(phase,'fairness')
    better = candidate.fairness>incumbent.fairness || ...
        (candidate.fairness==incumbent.fairness && candidate.totalBits>incumbent.totalBits);
else
    better = all(candidate.demandRatio>=s0) && candidate.totalBits>incumbent.totalBits;
end
end
