function lower=leo_v13_touch_resource(data,proxy,m,group)
% 在候选组处为本块重建切线；未选用户用截入合法干扰区间的反事实切点。
% 每条切线仍是全局速率下界；只有本次候选点的已选用户保证相切。
K=data.shape(1); ids=find(data.available(:,m)); [scale,~]=leo_service_adjustment(data);
lower=proxy.lower; lower.aBits(:,m)=0; lower.bBits(:,:,m)=0;
for t=find(data.slotToResource==m)
    if data.dataDurationS(t)<=0, continue; end
    C=zeros(K,K); C(:,ids)=data.design.beamPowerW(:,data.beamIndex(ids,m),t); C(1:K+1:end)=0;
    I=C*double(group); W=min(max(I,0),proxy.limits.maxW(:,t));
    line=leo_tangent_lower(data.design.signalW(:,t),data.design.noiseW(:,t),data.bandwidthHz,W);
    mask=double(data.available(:,m)); dt=data.dataDurationS(t);
    lower.aBits(:,m)=lower.aBits(:,m)+dt*scale.*line.alphaBps.*mask;
    lower.bBits(:,:,m)=lower.bBits(:,:,m)+dt*bsxfun(@times,scale.*line.omegaBpsPerW.*mask,C);
end
end
