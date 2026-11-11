function target = leo_certificate_targets(data)
%LEO_CERTIFICATE_TARGETS 吞吐证书必须说明所保持的公平门槛；旧数据默认为1。
floorValue=1;
if isfield(data,'certificateFairnessFloor'), floorValue=data.certificateFairnessFloor; end
target=floorValue*data.qosTargetBits;
end
