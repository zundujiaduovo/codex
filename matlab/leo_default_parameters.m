function p = leo_default_parameters()
%LEO_DEFAULT_PARAMETERS 参数集中入口；SI 单位，角度字段以 Deg 结尾。
% 接口标注：
% 输入：无；修改返回结构后传给主入口。
% 输出：p：全部物理、资源、问题与算法参数；SI 单位。
% 数值来源/假设见 README.md；未将演示参数冒充论文复现实验。
% [S1-S4] 系统、资源、功率；[G1-G6] 几何；[C1-C8] 信道及码本。
p.seed = 20261104;
p.constants.c = 299792458;             % 真空光速，m/s（精确定义）
p.constants.kB = 1.380649e-23;          % Boltzmann 常数，J/K（精确定义）
p.earth.aM = 6378137;                  % WGS-84 半长轴
p.earth.flattening = 1/298.257223563;   % WGS-84 扁率
p.earth.mu = 3.986004418e14;           % 地球引力参数，m^3/s^2
p.earth.rotationRadS = 7.292115e-5;

p.system.K = 32;
p.system.nRF = 8;
p.system.maxStreams = 8;              % L：32 个固定波束，最多激活 1/4
p.system.bandwidthHz = 20e6;
p.system.carrierHz = 2e9;             % S 波段场景，参见 3GPP TR 38.811
p.system.streamPowerW = 10;           % p0 始终固定，不能按组大小重分功率
p.system.maxPowerW = 80;              % 保持 p0=10 W，必须满足 L*p0<=Pmax
p.system.qosTargetBits = 1e6;          % 正的周期需求；不是业务队列上限

p.time.nSlots = 100;
p.time.slotDurationS = 0.01;          % 每个基本槽按块衰落建模
p.time.blockSlots = 5;               % 默认 50 ms/资源，M=20；块内固定组/码字
p.time.baseOverheadS = 0.001;
p.time.configOverheadS = 0.0002;      % 仅在每个资源的首槽扣除

p.users.centerLatDeg = 0;
p.users.centerLonDeg = 0;
p.users.radiusM = 200e3;              % 区域半径，自选仿真假设
p.users.altitudeM = 0;
p.orbit.altitudeM = 600e3;            % LEO 场景；圆轨道半径 aE+h
p.orbit.inclinationDeg = 53;
p.orbit.raanDeg = 0;
p.orbit.initialArgumentDeg = 0;
p.orbit.earthAngleAtEpochDeg = 0;     % 合成历元 ECI/ECEF z 轴转角

p.array.nX = 8;                      % 32 波束算例采用较宽主瓣，见 README
p.array.nY = 8;
p.array.spacingWavelength = [0.5, 0.5];
p.array.gridOversampling = 2;        % Mx=2Nx, My=2Ny，方案 C6
p.array.phaseBits = 3;               % 有限相移：0,45,...,315 度
p.array.nBeams = 32;                 % 离线从合法网格固定选择 32 个不同码字
p.array.scanMaxDeg = 26;             % 与 32 波束/200 km 区域匹配的固定扫描域
p.array.coverageGridSize = 41;        % 固定方向图验证网格（抽样）
p.coverage.minElevationDeg = 20;
p.coverage.maxArrayLossDb = 3;        % gmin=10^(-3/10)，方案示例

p.channel.elementGainDbi = 5;        % 扫描域内常数近似，不含 Na
p.channel.receiveGainDbi = 0;        % 单天线终端
p.channel.extraLossDb = 2;           % 固定附加损耗；非完整天气模型
p.channel.ricianKDb = 10;            % 待标定的实验起点，线性 kappa=10
p.channel.systemTemperatureK = 500;  % 已含接收机噪声，不再叠加 NF

p.statistics.totalRisk = 0.05;       % 周期服务向量的联合失效概率上限
p.statistics.serviceModel = 'periodic_chernoff'; % 'slot_union' 保留旧逐槽模型
p.statistics.independentSlots = true; % 与 leo_generate_fading 的基本槽独立假设一致
p.statistics.goodFadeThreshold = 0.25; % 预先固定，不用未来衰落调参
p.statistics.chernoffTilt = 2.5;     % theta_i * 最大单槽服务，正的无量纲常数
p.problem.referenceBits = [];        % [] -> sum(q_i)，与决策无关
p.problem.feasibilityTolerance = 1e-9; % 归一化约束容差，不改变数学约束
p.exhaustive = leo_exhaustive_options(); % 默认不启动；run_leo_exhaustive_demo 开启
p.surrogate.referenceMode = 'minimax'; % 切线/弦线；current_schedule 以预检见证相切
p.method = leo_method_options();     % 默认仅建模；run_leo_method_demo 开启两阶段 SB
end
