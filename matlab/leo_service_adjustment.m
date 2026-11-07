function [scale,margin] = leo_service_adjustment(data)
%LEO_SERVICE_ADJUSTMENT 周期证书的逐用户斜率和一次性风险余量；兼容旧数据。
scale = ones(data.shape(1),1); margin = zeros(data.shape(1),1);
if isfield(data.design,'serviceScale'), scale = data.design.serviceScale; end
if isfield(data.design,'serviceMarginBits'), margin = data.design.serviceMarginBits; end
end
