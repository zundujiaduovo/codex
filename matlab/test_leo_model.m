function test_leo_model()
%TEST_LEO_MODEL 无附加工具箱测试，包含独立复矩阵接收功率核对。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
p = leo_default_parameters();
p.time.nSlots = 8;
p.system.K = 12;
% 回归测试使用完整候选码本，专门验证物理链路；32 波束默认在问题测试覆盖。
p.array.nBeams = 405;
p.array.nX = 16; p.array.nY = 16; p.array.scanMaxDeg = 45;
m = run_leo_sinr(p);
p = m.parameters;
checks = 0;

% 1. WGS-84 在赤道/极点的独立闭式坐标与法向。
[r,n] = leo_geodetic_to_ecef([0,90],[0,0],[0,0],p.earth);
assert(norm(r(:,1)-[p.earth.aM;0;0])<1e-8);
assert(abs(r(3,2)-p.earth.aM*(1-p.earth.flattening))<1e-8);
assert(max(abs(sum(n.^2,1)-1))<1e-12); checks = checks+1;

% 2. 轨道半径不变；姿态正交、右手系，且 +z 指向地心。
radius = p.earth.aM+p.orbit.altitudeM;
assert(max(abs(sqrt(sum(m.orbit.ecefM.^2,1))-radius))<1e-7);
for t = 1:p.time.nSlots
    R = m.orbit.arrayToEcef(:,:,t);
    assert(norm(R.'*R-eye(3),'fro')<1e-12 && abs(det(R)-1)<1e-12);
    assert(norm(R(:,3)+m.orbit.ecefM(:,t)/radius)<1e-12);
end
checks = checks+1;

% 3. 固定码本等模/单位范数、有限相位、无重复、量化中心界 C9。
F = m.codebook.F;
assert(max(abs(sum(abs(F).^2,1)-1))<1e-12);
assert(max(abs(abs(F(:))-1/sqrt(p.array.nElements)))<1e-12);
phase = mod(angle(F(:)),2*pi)*2^p.array.phaseBits/(2*pi);
assert(max(abs(phase-round(phase)))<1e-12);
assert(size(unique(m.codebook.phaseIndex.','rows'),1)==m.codebook.nBeams);
assert(all(m.codebook.centerGain>=cos(pi/2^p.array.phaseBits)^2-1e-12));
checks = checks+1;

% 4. 单阵元 beta 不能重复计入 Na；噪声采用系统温度且为正。
expectedBeta = 10^((p.channel.elementGainDbi+p.channel.receiveGainDbi - ...
    p.channel.extraLossDb)/10)*(p.system.wavelengthM/(4*pi*m.geometry.rangeM(1)))^2;
assert(abs(m.channel.beta(1)/expectedBeta-1)<1e-12);
assert(all(m.channel.noiseW(:)>0)); checks = checks+1;

% 5. 独立 oracle：直接用 h_i^H W 得到各流功率，再计算 SINR。
assert(nnz(m.sinr.active)>0,'测试没有实际激活用户，不能视为通过。');
multi = 0;
for resource = 1:m.resources.nResources
    users = m.sinr.selectedUsers{resource};
    W = m.sinr.precoder{resource};
    assert(abs(norm(W,'fro')^2-p.system.streamPowerW*numel(users))<1e-10);
    multi = multi+(numel(users)>1);
    for t = m.resources.slots{resource}
        received = abs(m.fading.h(:,users,t)'*W).^2;
        for j = 1:numel(users)
            i = users(j);
            wanted = received(j,j);
            other = sum(received(j,[1:j-1,j+1:numel(users)]));
            gamma = wanted/(m.channel.noiseW(i,t)+other);
            assert(abs(gamma-m.sinr.gamma(i,t))<1e-10*max(1,gamma));
        end
    end
end
assert(multi>0,'必须测试非空多用户干扰。'); checks = checks+1;

% 6. 同一单用户的 SINR 等于瞬时 SNR，增加干扰后不能改善。
x = false(size(m.xExample));
i = find(m.xExample(:,1),1); x(i,1) = true;
single = leo_compute_sinr(p,m.resources,m.beams,m.channel,m.fading,m.link,m.codebook,x);
assert(abs(single.gamma(i,1)-m.fading.Z(i,1)*m.link.signalW(i,1)/m.channel.noiseW(i,1))<1e-10);
assert(single.gamma(i,1)>=m.sinr.gamma(i,1)-1e-12); checks = checks+1;

% 7. 空组合法：零功率、无激活、SINR 导出值零而 dB 为 -Inf。
empty = leo_compute_sinr(p,m.resources,m.beams,m.channel,m.fading,m.link,m.codebook,false(size(x)));
assert(~any(empty.active(:)) && all(empty.gamma(:)==0));
assert(all(empty.averageTransmitPowerW==0) && all(isinf(empty.gammaDb(:))));
checks = checks+1;

% 8. 明确拒绝非法输入：非二元、容量超限、同波束复用。
bad = double(x); bad(i,1) = 0.5;
expect_error(@() leo_compute_sinr(p,m.resources,m.beams,m.channel,m.fading,m.link,m.codebook,bad));
bad = false(size(x)); bad(:,1) = m.beams.available(:,1);
assert(nnz(bad(:,1))>p.system.maxStreams);
expect_error(@() leo_compute_sinr(p,m.resources,m.beams,m.channel,m.fading,m.link,m.codebook,bad));
fake = m.beams; fake.available(1:2,1) = true; fake.index(1:2,1) = 1;
bad = false(size(x)); bad(1:2,1) = true;
expect_error(@() leo_compute_sinr(p,m.resources,fake,m.channel,m.fading,m.link,m.codebook,bad));
checks = checks+1;

% 9. 相同 seed 可复现，入口不污染调用方的 RNG 状态。
before = rng;
again = run_leo_sinr(p);
after = rng;
assert(isequal(before,after) && isequal(m.fading.g,again.fading.g));
assert(isequal(m.users.ecefM,again.users.ecefM)); checks = checks+1;

% 10. 整块判据不能将“每槽各有最好波束”误当作一个固定波束可覆盖。
toy = p; toy.system.K = 1; toy.time.nSlots = 2; toy.time.blockSlots = 2;
toy.coverage.minGain = 0.8; toy.array.nX = 2; toy.array.nY = 1;
toy.array.nElements = 2; toy.array.spacingWavelength = [0.5,0.5];
rr = leo_build_resources(toy);
gg.directionArray = zeros(3,1,2);
gg.directionArray(:,1,1) = [0;0;1]; gg.directionArray(:,1,2) = [1;0;0];
gg.visible = true(1,2);
cc.F = [1,1;1,-1]/sqrt(2); cc.nBeams = 2;
bb = leo_assign_beams(toy,rr,gg,cc);
assert(~bb.available && bb.index==0); % 两槽分别被不同正交码字覆盖
rr.dataDurationS(2) = 0;
bb = leo_assign_beams(toy,rr,gg,cc);
assert(bb.available && bb.index==1); % 无数据槽不限制覆盖
rr.dataDurationS(:) = 0;
bb = leo_assign_beams(toy,rr,gg,cc);
assert(~bb.available && bb.index==0); checks = checks+1;

% 11. 多槽资源含尾部短块；首槽开销只扣一次，SINR 仍逐槽计算。
block = p; block.time.nSlots = 7; block.time.blockSlots = 3;
bm = run_leo_sinr(block);
assert(bm.resources.nResources==3);
assert(isequal(bm.resources.slotToResource,[1,1,1,2,2,2,3]));
assert(isequal(find(bm.resources.configOverheadS>0),[1,4,7]));
assert(all(all(bm.sinr.active(:,1:3)==repmat(bm.xExample(:,1),1,3))));
checks = checks+1;

% 12. 蒙特卡洛核对归一化 Rician 的 E[Z]=1，固定种子、宽裕统计容差。
previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
rng(11,'twister');
N = 200000;
mc = p; mc.system.K = N; mc.time.nSlots = 1; mc.array.nElements = 1;
mcGeometry.rangeM = repmat(600e3,N,1);
mcBeams.response = ones(1,N);
mcChannel.beta = ones(N,1);
samples = leo_generate_fading(mc,mcGeometry,mcBeams,mcChannel);
assert(abs(mean(samples.Z)-1)<0.005); checks = checks+1;

% 13. 无可见用户与零净时间均合法返回空组，不能伪造覆盖/传输。
off = p; off.orbit.initialArgumentDeg = 180;
hidden = run_leo_sinr(off);
assert(~any(hidden.beams.available(:)) && ~any(hidden.sinr.active(:)));
zero = p; zero.time.baseOverheadS = zero.time.slotDurationS;
zero.time.configOverheadS = 0;
idle = run_leo_sinr(zero);
assert(~any(idle.beams.available(:)) && ~any(idle.sinr.active(:)));
checks = checks+1;

% 14. K=T=Na=NB=L=1 时不得因 squeeze/维度塌缩产生错误。
one = leo_default_parameters();
one.system.K = 1; one.system.nRF = 1; one.system.maxStreams = 1;
one.time.nSlots = 1; one.array.nX = 1; one.array.nY = 1; one.array.nBeams = 1;
scalar = run_leo_sinr(one);
assert(scalar.sinr.active && isfinite(scalar.sinr.gamma) && scalar.sinr.gamma>0);
checks = checks+1;
fprintf('PASS: %d numerical/physical test groups.\n',checks);
end

function expect_error(action)
failed = false;
try
    action();
catch
    failed = true;
end
assert(failed,'预期输入检查拒绝该输入，但未触发异常。');
end
