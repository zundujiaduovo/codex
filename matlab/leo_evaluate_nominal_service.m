function service = leo_evaluate_nominal_service(data,x)
%LEO_EVALUATE_NOMINAL_SERVICE Z=1 的参考吞吐；不是期望速率或概率保证。
assert(isfield(data.design,'nominalSignalW'),'旧快照没有保存未折减链路系数。');
data.design.signalW = data.design.nominalSignalW;
data.design.beamPowerW = data.design.nominalBeamPowerW;
data.design.serviceScale = ones(data.shape(1),1);
data.design.serviceMarginBits = zeros(data.shape(1),1);
service = leo_evaluate_service(data,x);
service.scope = 'Reference at Z=1; neither expected throughput nor a reliability guarantee.';
end
