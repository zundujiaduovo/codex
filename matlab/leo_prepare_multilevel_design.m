function d = leo_prepare_multilevel_design(p,r,b,c,link)
%LEO_PREPARE_MULTILEVEL_DESIGN 先公共确定性校准，再冻结所有方法共用的多级证书。
% 无随机衰落样本输入；逐用户选参只用名义信道的公共可行日程。
legacy = p; legacy.statistics.serviceModel = 'periodic_chernoff';
d = leo_prepare_design_service(legacy,r,b,c,link);
raw = d; raw.serviceModel = 'slot_union';
raw.signalW = link.signalW; raw.beamPowerW = link.beamPowerW;
raw.serviceScale(:)=1; raw.serviceMarginBits(:)=0;
nominalProblem = leo_form_problem(p,r,b,raw);
o = leo_method_options(struct('randomInitialSchedules',0,'verbose',false));
anchor = leo_initial_schedules(nominalProblem,[],o);
data = nominalProblem.data; data.design = d;
old = leo_evaluate_service(data,anchor.x); best = old.userBits;
K = p.system.K; J = p.statistics.fadingLevels;
d.fadingLevels = (0:J)/J;
d.fadingMass = zeros(K,J+1);
d.fadingMass(:,1) = d.badFadeProbabilityUpper;
d.fadingMass(:,end) = 1-d.badFadeProbabilityUpper;
d.selectedReferenceFade = repmat(p.statistics.goodFadeThreshold,K,1);
d.selectedTilt = repmat(p.statistics.chernoffTilt,K,1);
d.selectedMultilevel = false(K,1);
for z = p.statistics.referenceFadeGrid
    [levels,mass] = leo_fading_floor_distribution(z,p.channel.ricianK,J);
    trial = raw;
    trial.signalW = z*link.signalW.*d.eventMask;
    trial.beamPowerW = bsxfun(@times,link.beamPowerW,reshape(z*double(d.eventMask),K,1,p.time.nSlots));
    noInterference = bsxfun(@times,r.dataDurationS,p.system.bandwidthHz/log(2)*log1p(trial.signalW./c.noiseW));
    maxBits = max(noInterference,[],2)*(1+1e-12); active = maxBits>0;
    data.design = trial; score = leo_evaluate_service(data,anchor.x);
    for tau = p.statistics.tiltGrid
        mgf = sum(mass.*exp(-tau*levels));
        alpha = max(0,-log(min(1,mgf+32*eps))/tau)*(1-1e-12);
        theta = zeros(K,1); theta(active)=tau./maxBits(active);
        margin = zeros(K,1); margin(active)=-log(d.userRisk(active))./theta(active);
        values = max(0,alpha*score.userBits-margin);
        take = active & values>best;
        if ~any(take), continue; end
        best(take)=values(take);
        d.signalW(take,:)=trial.signalW(take,:);
        d.beamPowerW(take,:,:)=trial.beamPowerW(take,:,:);
        d.zeta(take,:)=z*double(d.eventMask(take,:));
        d.serviceScale(take)=alpha; d.serviceMarginBits(take)=margin(take);
        d.maxSlotBits(take)=maxBits(take); d.thetaPerBit(take)=theta(take);
        d.fadingMass(take,:)=repmat(mass,nnz(take),1);
        d.selectedReferenceFade(take)=z; d.selectedTilt(take)=tau;
        d.selectedMultilevel(take)=true;
    end
end
d.serviceModel = 'periodic_multilevel';
d.guarantee = 'Multilevel fading-floor certificate; independent slots per user; fixed common parameters; joint risk budget is totalRisk.';
d.calibrationX = anchor.x; d.calibrationName = anchor.bestName;
d.legacyCalibrationBits = old.userBits; d.calibrationBits = best;
end
