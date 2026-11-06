function bits = leo_resource_group_services(data,m,groups)
%LEO_RESOURCE_GROUP_SERVICES R5-R6：一次计算所有合法组在一个资源的服务。
% 接口标注：
% 输入：data：原始设计模型；m：块号；groups：K×G 合法组。
% 输出：bits：K×G 原始块服务 bit，支持批量穷举评价。
% 原始低分位设计系数，逐基本槽累计；缓存只消除重复运算，不近似速率。
K = data.shape(1);
assert(size(groups,1)==K && all(groups(:)==0 | groups(:)==1));
assert(~any(any(bsxfun(@and,groups,~data.available(:,m)))));
assert(all(sum(groups,1)<=data.maxStreams));
ids = find(data.available(:,m));
codes = unique(data.beamIndex(ids,m));
for code = codes.'
    assert(all(sum(groups(data.beamIndex(:,m)==code,:),1)<=1));
end
X = double(groups);
bits = zeros(K,size(groups,2));
slots = find(data.slotToResource==m & data.dataDurationS>0);
for t = slots
    C = zeros(K,K);
    C(:,ids) = data.design.beamPowerW(:,data.beamIndex(ids,m),t);
    C(1:K+1:end) = 0;               % 自己的流不是干扰
    interference = C*X;
    sinr = bsxfun(@rdivide,data.design.signalW(:,t), ...
        bsxfun(@plus,data.design.noiseW(:,t),interference));
    bits = bits+data.dataDurationS(t)*data.bandwidthHz/log(2)*(X.*log1p(sinr));
end
end
