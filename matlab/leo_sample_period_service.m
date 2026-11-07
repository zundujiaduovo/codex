function result = leo_sample_period_service(data,x,kappa,nTrials,seed)
%LEO_SAMPLE_PERIOD_SERVICE 固定日程的独立衰落验证；不参与优化或参数选择。
% sumRate 是整周期 bit/周期秒数；输出 bit 供任意周期长度正确换算。
assert(isscalar(nTrials) && isfinite(nTrials) && nTrials>=1 && nTrials==fix(nTrials));
assert(isscalar(kappa) && isfinite(kappa) && kappa>=0 && isfield(data.design,'nominalSignalW'));
previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
rng(seed,'twister');
nominal = leo_evaluate_nominal_service(data,x); %#ok<NASGU> 校验硬约束
raw = data; raw.design.signalW = data.design.nominalSignalW;
raw.design.beamPowerW = data.design.nominalBeamPowerW;
interference = leo_schedule_interference(raw,x);
selection = double(x(:,data.slotToResource));
K = data.shape(1); T = numel(data.slotToResource); samples = zeros(K,nTrials);
for first = 1:100:nTrials
    last = min(nTrials,first+99); count = last-first+1;
    fading = abs(sqrt(kappa/(kappa+1))+ ...
        sqrt(1/(2*(kappa+1)))*(randn(K,T,count)+1i*randn(K,T,count))).^2;
    sinr = bsxfun(@times,raw.design.signalW,fading)./ ...
        bsxfun(@plus,raw.design.noiseW,bsxfun(@times,interference,fading));
    slot = bsxfun(@times,bsxfun(@times,selection,data.dataDurationS),log1p(sinr))*data.bandwidthHz/log(2);
    samples(:,first:last) = reshape(sum(slot,2),K,count);
end
ok = bsxfun(@ge,samples,data.qosTargetBits);
result.nTrials = nTrials; result.seed = seed;
result.meanTotalBits = mean(sum(samples,1));
result.meanUserBits = mean(samples,2);
result.meanUserQosRate = mean(ok(:));
result.jointSuccessRate = mean(all(ok,1));
result.jointFailures = sum(~all(ok,1));
% 独立验证样本的一侧 95% Clopper-Pearson 失效概率上限。
if result.jointFailures==nTrials, result.jointFailure95Upper = 1;
else, result.jointFailure95Upper = betaincinv(.95,result.jointFailures+1,nTrials-result.jointFailures); end
result.scope = 'Independent Monte Carlo validation of a fixed schedule; not a deterministic capacity bound.';
end
