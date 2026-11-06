function d = leo_prepare_design_service(p,r,b,c,link)
%LEO_PREPARE_DESIGN_SERVICE R1-R7：所有候选用户-基本槽的风险与设计系数。
% 接口标注：
% 输入：p/r/b/c/link：联合风险、资源、候选及固定链路系数。
% 输出：d：所有候选基本槽的风险/分位值、固定设计功率 W。
% 风险按有数据的基本槽计数，不能将固定块数 M 当作衰落事件数。
K = p.system.K; T = p.time.nSlots;
d.eventMask = false(K,T);
for t = 1:T
    if r.dataDurationS(t)>0
        d.eventMask(:,t) = b.available(:,r.slotToResource(t));
    end
end
d.nEvents = nnz(d.eventMask);
d.totalRisk = p.statistics.totalRisk;
d.risk = zeros(K,T);
d.zeta = zeros(K,T);
if d.nEvents>0
    d.risk(d.eventMask) = d.totalRisk/d.nEvents;
    d.zeta(d.eventMask) = leo_rician_power_quantile(d.risk(d.eventMask),p.channel.ricianK);
end
d.usedRisk = sum(d.risk(:));
assert(d.usedRisk<=d.totalRisk+1e-12);
d.signalW = d.zeta.*link.signalW;     % S，不是瞬时 Z*S_tilde
d.beamPowerW = zeros(size(link.beamPowerW));
for t = 1:T
    d.beamPowerW(:,:,t) = bsxfun(@times,d.zeta(:,t),link.beamPowerW(:,:,t));
end
d.noiseW = c.noiseW;
d.guarantee = 'All candidate user-slot events; union bound; no independence required.';
% 未传入 fading.g/Z/h，保证问题参数不窥视未来瞬时衰落。
end
