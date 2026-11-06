function link = leo_link_coefficients(p,r,b,c)
%LEO_LINK_COEFFICIENTS [P5] 与选择组无关的有用系数及用户-波束干扰系数。
% 接口标注：
% 输入：p/r/b/c：固定功率、资源、预指派码字、信道。
% 输出：link：K×T 信号系数与 K×NB×T 用户—波束干扰系数 W。
% beamPowerW(i,b,t) 使用受干扰用户 i 的 beta 和 a，保留全部旁瓣。
% 以后 cTilde(i,j,t)=beamPowerW(i,b.index(j,m),t)，只在 i~=j 时计干扰。
link.beamPowerW = zeros(size(b.gain));
link.signalW = zeros(p.system.K,p.time.nSlots);
for t = 1:p.time.nSlots
    scale = p.system.streamPowerW*p.array.nElements*c.beta(:,t);
    link.beamPowerW(:,:,t) = bsxfun(@times,scale,b.gain(:,:,t));
    m = r.slotToResource(t);
    users = find(b.available(:,m));
    if r.dataDurationS(t)<=0, continue; end
    for i = users.'
        link.signalW(i,t) = link.beamPowerW(i,b.index(i,m),t);
    end
end
end
