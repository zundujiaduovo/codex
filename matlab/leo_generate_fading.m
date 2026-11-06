function f = leo_generate_fading(p,g,b,c)
%LEO_GENERATE_FADING [C3-C4] 几何共同方向的归一化 Rician 瞬时样本。
% 接口标注：
% 输入：p/g/b/c：参数、几何、波束、大尺度信道。
% 输出：f：复 Rician 样本、功率 Z、Na×K×T 瞬时复信道。
% 散射项默认用户/槽独立；这是块模型假设，不宣称真实时间相关性。
% 大时延和主多普勒已补偿；phi 保留传播相位作为一致的复信道约定。
kappa = p.channel.ricianK;
f.phaseRad = -2*pi*mod(g.rangeM,p.system.wavelengthM)/p.system.wavelengthM;
xi = (randn(p.system.K,p.time.nSlots)+1i*randn(p.system.K,p.time.nSlots))/sqrt(2);
f.g = sqrt(kappa/(1+kappa))*exp(1i*f.phaseRad) + sqrt(1/(1+kappa))*xi;
f.Z = abs(f.g).^2;
f.h = complex(zeros(p.array.nElements,p.system.K,p.time.nSlots));
for t = 1:p.time.nSlots
    scale = sqrt(p.array.nElements*c.beta(:,t)).*f.g(:,t);
    f.h(:,:,t) = bsxfun(@times,b.response(:,:,t),scale.');
end
end
