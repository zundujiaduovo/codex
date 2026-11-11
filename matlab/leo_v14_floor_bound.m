function r=leo_v14_floor_bound(report,s0,iterations)
% 即使无LP工具箱，也优化真正含s0的有效对偶界；不同门槛不强制不同数值。
if nargin<3, iterations=150; end
d=report.problemData; cache=leo_prepare_upper_bounds(d); K=d.shape(1); M=d.shape(2);
lambda=zeros(K,1); best=Inf; trace=struct([]); [~,margin]=leo_service_adjustment(d);
for k=1:iterations
    bound=leo_original_upper_bound(d,cache,lambda,'throughput',s0);
    value=bound.value*d.referenceBits; best=min(best,value);
    w=lambda./d.qosTargetBits+1/d.referenceBits; relaxed=zeros(K,1);
    for m=1:M
        ids=find(d.available(:,m)); beams=unique(d.beamIndex(ids,m)); score=0; chosen=[]; cardinality=0;
        for count=1:min(d.maxStreams,numel(beams))
            winners=zeros(numel(beams),1); values=zeros(numel(beams),1);
            for b=1:numel(beams)
                ii=ids(d.beamIndex(ids,m)==beams(b)); [values(b),at]=max(w(ii).*cache.serviceByCardinality(ii,m,count)); winners(b)=ii(at);
            end
            [v,order]=sort(values,'descend'); candidate=sum(v(1:count));
            if candidate>score, score=candidate; chosen=winners(order(1:count)); cardinality=count; end
        end
        if cardinality>0, relaxed(chosen)=relaxed(chosen)+cache.serviceByCardinality(chosen,m,cardinality); end
    end
    gradient=s0-(relaxed-margin)./d.qosTargetBits;
    lambda=max(0,lambda+.5/k^.6*gradient/max(1,max(abs(gradient))));
    trace=leo_append_struct(trace,struct('iteration',k,'upperBits',value,'bestUpperBits',best,'floor',s0));
end
r=struct('upperBits',best*(1+1e-9)+1e-3,'fairnessFloor',s0,'iterations',iterations,'trace',trace, ...
 'kind','Floor-dependent original cardinality Lagrangian upper','floorUsed',true);
end
