function bits = leo_resource_service(data,m,group)
%LEO_RESOURCE_SERVICE 第 13.3 节：单个可行组只重算至多 L 个活跃用户。
% 输入：固定模型 data、块号 m、K×1 二元 group。输出：K×1 可加服务 A_im，尚未扣周期余量。
% 计算量 O(H_m L^2)，与批量组评价器完全相同的 R5-R6，非平均信道。
assert(numel(group)==data.shape(1) && all(group(:)==0 | group(:)==1));
ids = find(group);
assert(numel(ids)<=data.maxStreams && all(data.available(ids,m)));
assert(numel(unique(data.beamIndex(ids,m)))==numel(ids));
[scale,~] = leo_service_adjustment(data);
bits = zeros(data.shape(1),1);
if isempty(ids), return; end
for t = find(data.slotToResource==m & data.dataDurationS>0)
    C = data.design.beamPowerW(ids,data.beamIndex(ids,m),t);
    C(1:numel(ids)+1:end) = 0;
    sinr = data.design.signalW(ids,t)./(data.design.noiseW(ids,t)+sum(C,2));
    bits(ids) = bits(ids)+data.dataDurationS(t)*data.bandwidthHz/log(2)*scale(ids).*log1p(sinr);
end
end
