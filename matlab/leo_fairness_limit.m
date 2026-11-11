function limit = leo_fairness_limit(data)
%LEO_FAIRNESS_LIMIT 原模型无干扰放松给出的有限公平上界，不使用需求比例1封顶。
if ~leo_is_lexicographic(data), limit=1; return; end
if isfield(data,'fairnessUpperLimit'), limit=data.fairnessUpperLimit; return; end
[scale,margin]=leo_service_adjustment(data); maximum=zeros(data.shape(1),1);
for t=1:numel(data.slotToResource)
    m=data.slotToResource(t);
    bits=data.dataDurationS(t)*data.bandwidthHz/log(2)*scale.*log1p(data.design.signalW(:,t)./data.design.noiseW(:,t));
    bits(~data.available(:,m))=0; maximum=maximum+bits;
end
limit=max(0,min(max(0,maximum-margin)./data.qosTargetBits));
if limit>0, limit=limit*(1+1e-10)+1e-12; end
assert(isscalar(limit) && isfinite(limit) && limit>=0);
end
