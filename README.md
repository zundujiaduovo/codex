# LEO 固定资源 QoS：MATLAB 两阶段调度与统一对比

实现用户提供方案的基础模型、两阶段拉格朗日/SB 求解、原始有效界及第 13.3 节的基础模型对比。
默认 **32 个固定码本波束、最多并发 8 人、8 条射频链**，每个调度资源为 **50 ms（5 个 10 ms 基本槽）**。
输出物理模型、瞬时 SINR、统计 CSI 的低分位设计服务，以及两阶段原始混合整数非线性问题。
已接通切线/弦线、价格协调、QUBO/Ising、SB、约束修复、完整日程恢复与严格公平门槛下的吞吐阶段。
完整状态及未实施的可选扩展见 [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)。
算法参数与结果接口见 [METHOD.md](METHOD.md)，统一实验见 [BENCHMARKS.md](BENCHMARKS.md)，
每个函数的输入输出、方案位置和调用关系见 [FUNCTION_GUIDE.md](FUNCTION_GUIDE.md)。
迭代次数、收敛、资源使用等 **18 类完整图表**及重画入口见 [PLOTS.md](PLOTS.md)。
切线/弦线误差口径见 [TANGENT_CHORD.md](TANGENT_CHORD.md)。
详细数学形式、变量排列和回调接口见 [PROBLEM_FORMULATION.md](PROBLEM_FORMULATION.md)。
穷举算法、运行结果和规模限制见 [EXHAUSTIVE_BASELINE.md](EXHAUSTIVE_BASELINE.md)。

## 运行

如果 MATLAB 报“在不同结构体之间进行下标赋值”，请使用本次修复后的源码。
本次修复覆盖汇总、用户/日程 CSV 导出、迭代日志和图表规格中的空结构体追加。
已有其他版本的项目可先备份，再使用随包的修复脚本，仅替换相关赋值语句：

```matlab
addpath(fullfile(pwd,'tools'));
repair_leo_struct_arrays(pwd);        % 自动备份修改的文件；可重复执行
```

脚本要求当前目录是含 `matlab` 子目录的项目根目录。具体验证范围见 [VALIDATION.md](VALIDATION.md)。

在仓库根目录的 MATLAB 命令窗口执行（推荐 R2018b 或更新版本，仅基础 MATLAB）：

```matlab
addpath('matlab');
p = leo_default_parameters();
p.method.enabled = true;
model = run_leo_sinr(p);                   % 默认 32 用户/20 块的完整方法
small = run_leo_benchmarks('small');       % 基础算法/切点消融/小规模穷举
large = run_leo_benchmarks('default');     % 32 用户统一预算比较
run_leo_plot_results('results/plots_default/plot_data.mat','results/redraw_default'); % 重画本包已有结果
help leo_solve_schedule                   % 查看函数输入输出与说明
```

基础方法无需额外工具箱。可选 MILP 对比使用 MATLAB Optimization Toolbox 的 `intlinprog`
或 Octave 自带 GLPK；MIQP 对比需要 Gurobi，缺失时明确记录 `unavailable`。

先运行可完成的 **8 用户/3 块穷举对照**：

```matlab
addpath('matlab');
[model,comparison] = run_leo_exhaustive_demo();
model.exhaustive.x                  % 穷举得到的完整日程
model.exhaustive.completed          % 只有 true 才完成所有合法日程评价
```

原 32 用户/20 块约有 6.91×10^130 个合法日程，无法穷举；默认主函数建立模型及切线/弦线代理：

```matlab
addpath('matlab');
model = run_leo_sinr();
gamma = model.sinr.gamma;             % K x T，线性瞬时 SINR
gammaDb = model.sinr.gammaDb;         % K x T，dB
active = model.sinr.active;           % 只有这些位置实际传输
disp(gammaDb(active));
PF = model.problem.stage1;           % 原始公平优先问题，含目标和约束回调
PV = model.problem.stage2Example;    % 预检见证公平值下的第二阶段模板
model.problem.precheck              % 每用户至少一次服务的最大流预检
proxy = model.surrogate;             % 默认 minimax 切线与完整区间弦上界
model.exampleBounds                 % 同一示例日程的下界/原式/上界

test_leo_model();                     % 物理约束与数值一致性检查
test_leo_problem();                   % 风险、服务、原始问题形成检查
test_leo_exhaustive();                % 全日程穷举与独立二元枚举检查
test_leo_surrogate();                 % 切线/弦线、二次服务和误差预算
test_leo_method();                    % QUBO/Ising、SB、价格、原始上界和两阶段验收
test_leo_benchmark();                 % 原始增量基线、MILP 等价与对比公平性
test_leo_plots();                     % 迭代计数、收敛时间、图表数据及缺失值
```

修改参数和保存结果：

```matlab
p = leo_default_parameters();
p.system.K = 64;
p.time.blockSlots = 5;               % 固定用户组/码字保持 5 个基本槽
model = run_leo_sinr(p);
if ~exist('results','dir'), mkdir('results'); end
snapshot = rmfield(model,'problem'); % 数值数据跨 MATLAB/Octave 保存，不序列化函数句柄
save('results/leo_model.mat','snapshot','-v7');
```

参数改完后由入口统一校验并更新派生量，例如波长、阵元数、网格、线性 Rician 因子。
修改用户区域时，请同步检查轨道位置和覆盖输出；程序不会自动把卫星挪到用户上空。
随机种子固定，入口退出时恢复调用方随机数状态。无后台服务、外部数据或 MATLAB 附加工具箱依赖。
GNU Octave 实际运行及检查结果见 [VALIDATION.md](VALIDATION.md)；尚未在 MATLAB 本体中运行。

## 本轮默认物理参数的配套调整

上一版是 16×16 阵列、45° 扫描半角、405 个码字。直接将这个宽扫描域的码本减到 32 个，
默认用户中只有 6 人存在可服务资源，会令全用户公平问题的最优值为 0。
因此本版默认改为 **8×8 阵列、26° 扫描半角**，其余用户区域、3 dB 覆盖门槛和单流功率保持原值。
默认 32 位用户都有可服务机会；阵列相干增益也相应从 256 降到 64，代码中不会保留旧增益。
这是匹配固定 32 波束的仿真配置调整，不是新引用的论文参数，也不是对任意用户分布的覆盖保证。

候选仍由固定过采样网格生成，离线在固定验证点上依次选取覆盖增量最大的码字，最终冻结 32 个。
子集选择不读取用户位置、随机信道或调度结果；空洞按真实量化方向图报告。
默认扫描验证点约 0.48% 未达到门槛，所以仍不宣称整个连续扫描域无空洞。
若需要恢复原阵列，可设置 `p.array.nX=16; p.array.nY=16; p.array.scanMaxDeg=45;`；
`p.array.nBeams=32` 保持不变时，应查看可服务性预检并接受其零公平结论，或另行设计覆盖区域。

## 参数依据与待标定假设

文献模型依据与数值假设分开列出。参考链接来自方案及公开标准；本次联网获取论文全文返回 403，
因此**没有逐表核验论文的仿真参数，也不将下面的自选数值标为论文原值**。
这些参数用于跑通模型、检查数量级；正式论文实验应按目标终端、星载硬件和测量条件标定。

| 参数 | 默认值 | 依据/用途 |
|---|---:|---|
| 地球椭球 | WGS-84，a=6378137 m，1/f=298.257223563 | 标准地球模型 [3][4] |
| 光速、Boltzmann 常数 | 299792458 m/s；1.380649×10⁻²³ J/K | SI 精确定义 |
| 轨道高度、频率 | 600 km；2 GHz | 采用 3GPP NTN 常见 LEO/S 波段场景尺度 [5]；本实现采用简化圆轨道 |
| 信道模型 | 几何共同方向、归一化 Rician | 方案 C1–C4；统计 CSI 建模背景 [1] |
| 码本 | 固定二维过采样网格 | 方案 C5–C8；LEO 码本背景 [2] |
| 阵列、网格、相位 | 8×8；16×16 候选网格；3 bit | 32 波束配套实验设置；2 倍网格和 3 bit 来自方案示例 |
| 固定码本大小 | 32 | 用户指定；从去重合法候选中离线选择并冻结 |
| 阵元间距 | λ/2 | 方案限定范围内的常用 UPA 设置 |
| 扫描半角、最低仰角 | 26°；20° | 32 波束配套覆盖假设，非多人 SINR 保证 |
| 归一化覆盖门槛 | 10^(-3/10)≈0.5012 | 方案 G5 的 3 dB 示例 |
| 用户数、区域 | 32 人；赤道附近半径 200 km | 自选可复现实验；位置周期内固定 |
| 轨道倾角/升交点赤经/初始幅角 | 53°/0°/0° | 合成星历假设，不对应某颗真实卫星 |
| 射频链、最大同时用户数 | 8；8 | 与用户指定的 32 波束、1/4 激活比例一致 |
| 每流功率/预算 | 10 W/80 W | 保持固定 p0，预算配套增加以满足 Lp0≤Pmax |
| 带宽 | 20 MHz | 自选公共带宽；窄带/平坦等效信道近似 |
| 单阵元/终端天线增益 | 5 dBi/0 dBi | 自选常数增益；整阵列增益 Na 单独计算 |
| 附加功率损耗 | 2 dB | 简化常数损耗，不是完整雨衰/气体吸收模型 |
| Rician K 因子 | 10 dB（线性 10） | 待测量标定的实验起点，非固定标准要求 |
| 系统噪声温度 | 500 K | 自选等效系统温度；N=kB·Tsys·B，不再叠加噪声系数 |
| 周期/基本时隙 | 100×10 ms=1 s | 离散块模型设置，非声明真实散射相干时间 |
| 调度块 | 5 槽=50 ms；20 块/周期 | 用户要求小时间块；50 ms 是可调整实验设置 |
| 基础/配置开销 | 1 ms/0.2 ms | 块首槽净 8.8 ms，其余净 9 ms；每完整块净 44.8 ms |
| 周期需求 q_i | 1 Mbit/人 | 用于累计 QoS；正公平预检不等于所有需求达标 |
| 周期总风险 ε_tot | 0.05 | 自选；R1–R7 对全部候选用户—基本槽联合计风险 |
| 吞吐归一化 D_ref | sum(q_i)=32 Mbit | 默认与决策无关，也可指定正数 |

## 函数与公式对应

每个建模环节在独立 `.m` 函数中，中文注释标注公式编号。

| 函数 | 内容 |
|---|---|
| `leo_default_parameters` / `leo_validate_parameters` | 参数入口、单位、约束和派生量 |
| `leo_build_resources` | S2–S4：资源映射、净数据时间、采样时刻 |
| `leo_generate_users` / `leo_geodetic_to_ecef` | G1–G2：固定用户、ECEF 与椭球法向 |
| `leo_predict_orbit` | 连续圆轨道、ECI→ECEF、自洽阵列姿态 |
| `leo_compute_geometry` | G3–G4：距离、仰角、阵列方向、远场检查 |
| `leo_array_response` | C1：单位范数 UPA 阵列响应 |
| `leo_build_codebook` | C5–C9：预定网格、相位量化、规范化、去重 |
| `leo_select_codebook` | 从固定候选中离线选择指定数量的码字 |
| `leo_check_codebook_coverage` | 真实量化方向图的扫描域抽样检查 |
| `leo_assign_beams` | G5–G6：整资源最差增益最大化，同分最小编号 |
| `leo_large_scale_channel` | C2、P4：单阵元大尺度增益和噪声功率 |
| `leo_generate_fading` | C3–C4：归一化 Rician、复信道 h |
| `leo_link_coefficients` | P5：固定有用系数和用户—波束干扰系数 |
| `leo_example_selection` | 演示合法激活组，非 QoS 优化算法 |
| `leo_compute_sinr` | P1、P3、P6：有效预编码、平均功率和瞬时 SINR |
| `leo_rician_power_cdf` / `leo_rician_power_quantile` | R2：Rician 功率 CDF / 低分位，无统计工具箱 |
| `leo_prepare_design_service` | R1–R7：风险预算、低分位增益、固定设计系数 |
| `leo_evaluate_service` | R5–R6：原始设计速率、资源及周期服务、实际设计公平 |
| `leo_build_hard_constraints` | O1：二元变量上下界、人数/同码字限制 |
| `leo_precheck_positive_fairness` | 第 6.4 节：最大流检查正公平可服务性 |
| `leo_form_problem` / `leo_form_stage2` | O2、O4：两个阶段的变量、目标及约束接口 |
| `leo_problem_objective` / `leo_problem_nonlcon` | 原始目标与累计 QoS 的数值回调 |
| `leo_check_problem_point` | 已给定点的可行性检查，不进行优化 |
| `leo_exhaustive_size` / `leo_exhaustive_options` | 搜索规模与计算预算 |
| `leo_enumerate_resource_groups` / `leo_resource_group_services` | 所有合法组及其原始设计服务 |
| `leo_exhaustive_search` | 完整日程字典序穷举，明确完成状态 |
| `leo_compare_schedules` / `run_leo_exhaustive_demo` | 共用模型的算法比较与小规模对照入口 |
| `leo_rate_and_derivatives` / `leo_interference_limits` | T1–T3：速率导数、合法干扰上限 |
| `leo_tangent_lower` / `leo_chord_upper` | T4、T7–T10：切线、弦线与 minimax 切点 |
| `leo_build_service_surrogates` / `leo_assemble_quadratic_service` | T5–T6：二次服务系数、当前点相切及误差预算 |
| `leo_schedule_interference` / `leo_evaluate_quadratic_service` | 给定日程的干扰与二次服务评价 |
| `leo_evaluate_service_bounds` / `leo_check_surrogate_groups` | 原式夹逼、全合法组及误差预算检查 |
| `run_leo_surrogate_demo` | 在原始穷举最优日程上对照切线/弦线 |
| `run_leo_sinr` | 串联以上模型并返回结构体 |

## SINR 接口和数据维度

设当前资源是 m，接收用户是 i：

```text
S_tilde(i,t)   = p0 * Na * beta(i,t) * |a(i,t)^H f(b(i,m))|^2
c_tilde(i,j,t) = p0 * Na * beta(i,t) * |a(i,t)^H f(b(j,m))|^2
gamma(i,t)     = Z(i,t)*S_tilde(i,t) /
                 (N(i,t) + Z(i,t)*sum_{j~=i} c_tilde(i,j,t)*x(j,m))
```

干扰用 **i 的信道及衰落 Z(i,t)**。不使用 j 的信道计算 i 受到的干扰。
`F_BB=sqrt(p0)*I`，所以 `W=sqrt(p0)*F_RF`，组大小改变时不重新归一化总功率。
平均发射功率为 `p0*人数`，适用于独立、零均值、单位功率数据流，非峰值功率约束。

| 字段 | 维度 | 含义 |
|---|---|---|
| `users.ecefM` / `orbit.ecefM` | 3×K / 3×T | 用户/卫星坐标 |
| `orbit.arrayToEcef` | 3×3×T | 阵列到 ECEF 的旋转 |
| `geometry.directionArray` | 3×K×T | 阵列坐标系单位出射方向 |
| `codebook.F` | Na×NB | 固定有限码本；默认 NB=32 |
| `beams.available` / `beams.index` | K×M | v_im 与 b_im；不可用编号为 0 |
| `beams.gain` | K×NB×T | 归一化实际阵列增益，保留非零旁瓣 |
| `channel.beta` / `channel.noiseW` | K×T | 单阵元功率增益 / 接收噪声 W |
| `fading.g` / `fading.Z` / `fading.h` | K×T / K×T / Na×K×T | 瞬时复衰落、功率衰落、复信道 |
| `link.signalW` | K×T | S_tilde，不含瞬时 Z |
| `link.beamPowerW` | K×NB×T | 接收用户—发射波束固定功率系数，不含 Z |
| `xExample` | K×M | 仅用于运行示例的选择矩阵 |
| `sinr.gamma` / `sinr.gammaDb` | K×T | 瞬时 SINR，线性 / dB |
| `sinr.active` | K×T | 是否真实激活且存在数据时间 |
| `sinr.referenceZ1` | K×T | Z=1 的确定性参考，**不是平均 SINR** |
| `sinr.desiredPowerW` / `sinr.interferencePowerW` | K×T | 含 Z 的瞬时信号/干扰功率 |
| `design.risk` / `design.zeta` | K×T | 候选基本槽风险与确定性低分位增益 |
| `design.signalW` / `design.beamPowerW` | K×T / K×NB×T | R4 的设计有用/干扰系数，含 zeta |
| `problem.hard.index` | K×M | x(:) 中的变量位置；块内保持相同 x |
| `problem.stage1` | 结构体 | 640 个二元变量 + 连续公平比例 s（默认） |
| `problem.stage2Example` | 结构体 | 基于预检可行见证形成的吞吐改进问题模板 |

不额外存储 K×K×T 的干扰张量。任意可用 j 的系数可取：

```matlab
t = 1; m = model.resources.slotToResource(t);
j = find(model.beams.available(:,m),1);
cFromJ = model.link.beamPowerW(:,model.beams.index(j,m),t);
cFromJ(j) = 0;                       % 自己的流不是自身干扰
```

后续优化器提供合法 `x` 后，直接调用：

```matlab
result = leo_compute_sinr(model.parameters,model.resources,model.beams, ...
    model.channel,model.fading,model.link,model.codebook,x);
```

未选中或没有数据时间的位置导出 `gamma=0`、`gammaDb=-Inf`，须配合 `active` 掩码统计。
SINR 根据接收信号功率分解计算；本版由低分位 SINR 生成 Shannon 设计速率与服务，未生成调制波形。

## 模型边界

- 几何和信道以每槽有效数据区间中点的值保持整槽。G5 检查该离散模型全部有效槽，
  **不认证连续运动中所有时刻的覆盖**；连续模式需要增加 G7–G8 的裕量/区间检查。
- 码本先于用户生成固定。所有方向图空洞按实际结果报告，用户仍按最差增益做物理过滤。
  不因为某个用户未覆盖就改变码本、强制提升增益或删除其需求。
- 星历采用中心引力圆轨道及匀速地球自转；合成历元角度明确给定。
  未使用真实 UTC 星历、岁差章动、J2、TLE 或 SGP4。
- 用户由球面帽采样后映射 WGS-84；不声称严格椭球等面积。
- 散射项默认用户/槽独立，共同空间方向近似；主要时延和多普勒假定已补偿。
  相位保留几何传播相位，SINR 对共同相位不敏感。残余 ICI、频率选择性、波束斜视和天气相关衰落未建模。
- `qosTargetBits` 是目标而非队列上限。轮换示例和最大流见证不是优化解。
  问题模板 `problem.solved` 和各阶段 `solved` 均为 false；实际穷举完成状态见 `model.exhaustive`。

## 参考资料

1. Li You 等，*Massive MIMO Transmission for LEO Satellite Communications*，2020：
   https://arxiv.org/abs/2002.08148 。几何/统计 CSI 模型背景。
2. Palacios 等，*A Hybrid Beamforming Design for Massive MIMO LEO Satellite Communications*，2021：
   https://www.frontiersin.org/journals/space-technologies/articles/10.3389/frspt.2021.696464/full 。
   固定二维码本背景；本实现严格采用方案规定的全连接有限相位和固定对角数字预编码。
3. ESA Navipedia，*Transformations between ECEF and ENU coordinates*：
   https://gssc.esa.int/navipedia/index.php/Transformations_between_ECEF_and_ENU_coordinates 。
4. NGA，*World Geodetic System 1984*：https://earth-info.nga.mil/index.php?dir=wgs84&action=wgs84 。
5. 3GPP TR 38.811，*Study on New Radio (NR) to support non-terrestrial networks*：
   https://www.3gpp.org/ftp/Specs/archive/38_series/38.811/ 。场景尺度参考；未声称实现完整 3GPP 信道。
