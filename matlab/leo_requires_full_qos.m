function yes = leo_requires_full_qos(data)
%LEO_REQUIRES_FULL_QOS 历史模型默认 false；V5 主入口强制统一全员门槛。
yes = isfield(data,'requireFullQos') && data.requireFullQos && ~leo_is_lexicographic(data);
end
