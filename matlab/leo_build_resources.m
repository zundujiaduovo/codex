function r = leo_build_resources(p)
%LEO_BUILD_RESOURCES [S2-S4] 连续不重叠固定资源、开销及槽内采样时刻。
% 接口标注：
% 输入：p：已校验参数。
% 输出：r：M 个固定块、槽到块映射、采样时刻及净数据时间 s。
T = p.time.nSlots;
H = p.time.blockSlots;
r.nResources = ceil(T/H);
r.slots = cell(1,r.nResources);
r.slotToResource = zeros(1,T);
r.durationS = repmat(p.time.slotDurationS,1,T);
r.baseOverheadS = repmat(p.time.baseOverheadS,1,T);
r.configOverheadS = zeros(1,T);
for m = 1:r.nResources
    slots = (m-1)*H+1:min(m*H,T);
    r.slots{m} = slots;
    r.slotToResource(slots) = m;
    r.configOverheadS(slots(1)) = p.time.configOverheadS;
end
r.dataDurationS = r.durationS-r.baseOverheadS-r.configOverheadS;
% 假定开销位于槽首，在有效数据段中点取块系数；不认证连续运动。
r.sampleTimeS = (0:T-1)*p.time.slotDurationS + ...
    r.baseOverheadS+r.configOverheadS+r.dataDurationS/2;
end
