function c = leo_large_scale_channel(p,g)
%LEO_LARGE_SCALE_CHANNEL [C2,P4] 单阵元 beta、自由空间损耗、kB*Tsys*B。
% 接口标注：
% 输入：p：链路及噪声参数；g：距离与几何。
% 输出：c：K×T 单阵元功率增益 beta、噪声功率 W。
freeSpace = (p.system.wavelengthM./(4*pi*g.rangeM)).^2;
c.freeSpaceLossDb = -10*log10(freeSpace);
c.beta = 10^((p.channel.elementGainDbi+p.channel.receiveGainDbi - ...
    p.channel.extraLossDb)/10)*freeSpace;
c.noiseW = repmat(p.constants.kB*p.channel.systemTemperatureK* ...
    p.system.bandwidthHz,p.system.K,p.time.nSlots);
end
