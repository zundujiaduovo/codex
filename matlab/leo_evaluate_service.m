function service = leo_evaluate_service(data,x,requireFeasibleBinary)
%LEO_EVALUATE_SERVICE R5-R6、O3-O4：原始设计速率及跨块累计服务（bit）。
% 接口标注：
% 输入：data：固定设计模型；x：K×M 日程；可选 requireFeasibleBinary。
% 输出：service：逐槽/逐块/逐用户 bit、最差需求比、公平和净总服务。
% 默认校验合法二元日程。false 仅供问题回调在 [0,1] 盒内计算连续延拓。
if nargin<3, requireFeasibleBinary = true; end
assert(isequal(size(x),data.shape) && all(isfinite(x(:))));
assert(all(x(:)>=0 & x(:)<=1),'评价器定义域为 [0,1]。');
if requireFeasibleBinary
    assert(all(x(:)==0 | x(:)==1),'日程必须二元。');
    assert(all(x(:)<=data.hard.upper),'不可用用户不能激活。');
    assert(all(data.hard.A*double(x(:))<=data.hard.rhs),'人数/同码字约束不满足。');
end
K = data.shape(1); M = data.shape(2); T = numel(data.slotToResource);
service.gamma = zeros(K,T);
service.rateBps = zeros(K,T);         % 含 x_i，仅对选中用户计服务
service.slotBits = zeros(K,T);
service.resourceBits = zeros(K,M);
for t = 1:T
    if data.dataDurationS(t)<=0, continue; end
    m = data.slotToResource(t);
    for i = find(data.available(:,m)).'
        others = find(data.available(:,m) & (1:K).'~=i);
        weights = reshape(data.design.beamPowerW(i,data.beamIndex(others,m),t),[],1);
        interference = weights.'*double(x(others,m));
        sinr = data.design.signalW(i,t)/(data.design.noiseW(i,t)+interference);
        service.gamma(i,t) = x(i,m)*sinr;
        service.rateBps(i,t) = x(i,m)*data.bandwidthHz*log1p(sinr)/log(2);
    end
    service.slotBits(:,t) = data.dataDurationS(t)*service.rateBps(:,t);
    service.resourceBits(:,m) = service.resourceBits(:,m)+service.slotBits(:,t);
end
service.userBits = sum(service.resourceBits,2);
service.totalBits = sum(service.userBits);
service.demandRatio = service.userBits./data.qosTargetBits;
service.fairness = min(1,min(service.demandRatio));
service.normalizedThroughput = service.totalBits/data.referenceBits;
% q_i 是 QoS 目标，不把 service.userBits 裁剪到 q_i。
end
