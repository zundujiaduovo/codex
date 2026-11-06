function out = leo_compute_sinr(p,r,b,c,f,link,cb,x)
%LEO_COMPUTE_SINR [P1,P3,P5-P6] 给定 KxM 合法二元选择矩阵的瞬时 SINR。
% 接口标注：
% 输入：p/r/b/c/f/link/cb：完整物理结构；x：K×M 合法二元日程。
% 输出：out：K×T 瞬时 SINR（线性及 dB）、激活掩码、信号/干扰功率 W。
% 非激活/无数据槽置零（导出约定）；必须同时用 active 掩码解释。
assert(isequal(size(x),[p.system.K,r.nResources]),'x 必须为 K x M。');
assert(all(x(:)==0 | x(:)==1),'x 必须为二元矩阵。');
assert(~any(x(:) & ~b.available(:)),'x 选择了物理不可用用户。');
out.active = false(p.system.K,p.time.nSlots);
out.gamma = zeros(p.system.K,p.time.nSlots);
out.desiredPowerW = zeros(size(out.gamma));
out.interferencePowerW = zeros(size(out.gamma));
out.referenceZ1 = zeros(size(out.gamma)); % Z=1 参考，不是 E[SINR]
out.precoder = cell(1,r.nResources);
out.selectedUsers = cell(1,r.nResources);
out.averageTransmitPowerW = zeros(1,r.nResources);
for m = 1:r.nResources
    users = find(x(:,m)); beams = b.index(users,m);
    assert(numel(users)<=p.system.maxStreams,'激活流数超过 L。');
    assert(numel(unique(beams))==numel(beams),'同一波束不能承载多个独立流。');
    out.selectedUsers{m} = users;
    out.precoder{m} = sqrt(p.system.streamPowerW)*cb.F(:,beams);
    out.averageTransmitPowerW(m) = p.system.streamPowerW*numel(users);
    for t = r.slots{m}
        if r.dataDurationS(t)<=0, continue; end
        out.active(users,t) = true;
        for a = 1:numel(users)
            i = users(a);
            others = beams([1:a-1,a+1:numel(users)]);
            interference = sum(link.beamPowerW(i,others,t));
            S = link.signalW(i,t);
            Z = f.Z(i,t);  % 同一接收端所有流共享同一个 Z_i,t
            out.desiredPowerW(i,t) = Z*S;
            out.interferencePowerW(i,t) = Z*interference;
            out.gamma(i,t) = Z*S/(c.noiseW(i,t)+Z*interference);
            out.referenceZ1(i,t) = S/(c.noiseW(i,t)+interference);
        end
    end
end
out.gammaDb = 10*log10(out.gamma);     % 未激活处为 -Inf
end
