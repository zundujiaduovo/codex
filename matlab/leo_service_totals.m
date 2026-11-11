function service = leo_service_totals(data,resourceBits,clipNegative)
%LEO_SERVICE_TOTALS 先跨资源累计 A，再扣一次风险余量；不逐块截断。
% resourceBits 是可加的 A 分量；userBits 是周期保证 G=[A-margin]_+。
% 二次代理传 false，保留有符号下界供价格反馈，不能把负下界裁掉。
if nargin<3, clipNegative = true; end
[~,margin] = leo_service_adjustment(data);
service.resourceBits = resourceBits;
service.effectiveUserBits = sum(resourceBits,2);
service.signedUserBits = service.effectiveUserBits-margin;
service.guaranteedUserBits = max(0,service.signedUserBits);
service.userBits = service.signedUserBits;
if clipNegative, service.userBits = service.guaranteedUserBits; end
service.totalBits = sum(service.userBits);
service.demandRatio = service.userBits./data.qosTargetBits;
service.fairness = leo_fairness_from_ratios(data,service.demandRatio);
service.qosCompletion=min(1,min(service.demandRatio)); % 仅为QoS达标辅助指标，不用于V12优化排序。
service.normalizedThroughput = service.totalBits/data.referenceBits;
end
