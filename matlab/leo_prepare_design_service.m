function d = leo_prepare_design_service(p,r,b,c,link)
%LEO_PREPARE_DESIGN_SERVICE 周期 Chernoff 证书或旧 R1-R7 逐槽联合证书。
% 接口标注：
% 输入：p/r/b/c/link：联合风险、资源、候选及固定链路系数。
% 输出：d：固定阈值/分位功率 W、逐用户服务斜率及周期风险余量。
% 旧模型风险按候选基本槽计数；新模型风险按用户分配并要求槽间独立。
K = p.system.K; T = p.time.nSlots;
d.eventMask = false(K,T);
for t = 1:T
    if r.dataDurationS(t)>0
        d.eventMask(:,t) = b.available(:,r.slotToResource(t));
    end
end
d.nEvents = nnz(d.eventMask);
d.totalRisk = p.statistics.totalRisk;
d.serviceModel = p.statistics.serviceModel;
d.risk = zeros(K,T);
d.zeta = zeros(K,T);
if strcmp(d.serviceModel,'slot_union')
    if d.nEvents>0
        d.risk(d.eventMask) = d.totalRisk/d.nEvents;
        d.zeta(d.eventMask) = leo_rician_power_quantile(d.risk(d.eventMask),p.channel.ricianK);
    end
    d.usedRisk = sum(d.risk(:));
    d.guarantee = 'All candidate user-slot events; union bound; no independence required.';
else
    % 固定日程的周期服务证书：见 PERIODIC_QOS.md。风险按用户分配。
    assert(isequal(p.statistics.independentSlots,true));
    d.userRisk = repmat(d.totalRisk/K,K,1);
    d.usedRisk = sum(d.userRisk);
    d.zeta(d.eventMask) = p.statistics.goodFadeThreshold;
    [~,d.badFadeProbabilityUpper] = leo_rician_power_cdf( ...
        p.statistics.goodFadeThreshold,p.channel.ricianK);
    d.guarantee = 'Period accumulated service; independent slots within each user; fixed schedule before fading.';
end
assert(d.usedRisk<=d.totalRisk+1e-12);
d.signalW = d.zeta.*link.signalW;     % S，不是瞬时 Z*S_tilde
d.beamPowerW = zeros(size(link.beamPowerW));
for t = 1:T
    d.beamPowerW(:,:,t) = bsxfun(@times,d.zeta(:,t),link.beamPowerW(:,:,t));
end
d.noiseW = c.noiseW;
d.nominalSignalW = link.signalW;
d.nominalBeamPowerW = link.beamPowerW;
d.serviceScale = ones(K,1);
d.serviceMarginBits = zeros(K,1);
if strcmp(d.serviceModel,'periodic_chernoff')
    noInterferenceBits = bsxfun(@times,r.dataDurationS, ...
        p.system.bandwidthHz/log(2)*log1p(d.signalW./d.noiseW));
    d.maxSlotBits = max(noInterferenceBits,[],2)*(1+1e-12);
    active = d.maxSlotBits>0;
    d.thetaPerBit = zeros(K,1);
    tilt = p.statistics.chernoffTilt;
    d.thetaPerBit(active) = tilt./d.maxSlotBits(active);
    prob = d.badFadeProbabilityUpper;
    % h(b)=-log(p+(1-p)*exp(-theta*b))/theta 为凹函数；弦斜率给下界。
    if prob==0, alpha = 1;
    elseif tilt>1, alpha = -log(prob+(1-prob)*exp(-tilt))/tilt;
    else, alpha = -log1p((1-prob)*expm1(-tilt))/tilt; end
    d.serviceScale(:) = max(0,alpha*(1-1e-12));
    d.serviceMarginBits(active) = -log(d.userRisk(active))./d.thetaPerBit(active);
    % 完全不可服务的用户 G=0；不作除零或虚构正保证。
    d.serviceScale(~active) = 0;
end
% 未传入 fading.g/Z/h，保证问题参数不窥视未来瞬时衰落。
end
