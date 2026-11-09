function certificate = leo_certify_period_qos(data,x,targetBits)
%LEO_CERTIFY_PERIOD_QOS 固定日程的直接 Chernoff 检查，不读取瞬时衰落样本。
% 这里使用逐槽 log-MGF；搜索使用它的线性弦下界，故本检查可能更紧。
% targetBits 默认 q；各用户成功事件联合概率 >= jointSuccessLower。
assert(isfield(data.design,'serviceModel') && any(strcmp(data.design.serviceModel,{'periodic_chernoff','periodic_multilevel'})));
if nargin<3, targetBits = data.qosTargetBits; end
assert(numel(targetBits)==data.shape(1) && all(isfinite(targetBits(:))) && all(targetBits(:)>=0));
targetBits = targetBits(:);
raw = data; raw.design.serviceScale = ones(data.shape(1),1);
raw.design.serviceMarginBits = zeros(data.shape(1),1);
threshold = leo_evaluate_service(raw,x);
theta = data.design.thetaPerBit;
p = data.design.badFadeProbabilityUpper;
exponent = bsxfun(@times,theta,threshold.slotBits);
if strcmp(data.design.serviceModel,'periodic_multilevel')
    logMgf = zeros(size(exponent));
    for i=1:data.shape(1)
        positive = data.design.fadingMass(i,:)>0;
        logs = bsxfun(@minus,log(data.design.fadingMass(i,positive)).', ...
            data.design.fadingLevels(positive).'*exponent(i,:));
        top=max(logs,[],1);
        logMgf(i,:)=min(0,top+log(sum(exp(bsxfun(@minus,logs,top)),1))+64*eps);
    end
else
    logMgf = log1p((1-p)*expm1(-exponent));
    if p==0
        logMgf = -exponent;
    else
        large = exponent>1;
        logMgf(large) = log(p+(1-p)*exp(-exponent(large)));
    end
end
certificate.userFailureUpper = min(1,exp(theta.*targetBits+sum(logMgf,2)));
certificate.userFailureUpper(targetBits==0) = 0;
certificate.jointFailureUpper = min(1,sum(certificate.userFailureUpper));
certificate.jointSuccessLower = 1-certificate.jointFailureUpper;
certificate.certified = certificate.jointFailureUpper<=data.design.totalRisk;
certificate.scope = data.design.guarantee;
end
