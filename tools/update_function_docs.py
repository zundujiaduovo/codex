"""Regenerate MATLAB help annotations and the function index (no algorithm edits)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
# Each entry describes the public MATLAB interface, including units/dimensions.
IO = {
'leo_default_parameters': ('无；修改返回结构后传给主入口。', 'p：全部物理、资源、问题与算法参数；SI 单位。'),
'leo_validate_parameters': ('p：原始参数结构。', 'p：校验后参数，需求统一为 K×1，并更新所有派生量。'),
'leo_build_resources': ('p：已校验参数。', 'r：M 个固定块、槽到块映射、采样时刻及净数据时间 s。'),
'leo_generate_users': ('p：用户区域、数量及地球参数。', 'u：固定用户经纬度、3×K ECEF 坐标 m 和局部法向。'),
'leo_geodetic_to_ecef': ('latDeg/lonDeg/heightM：大地坐标；earth：WGS-84 参数。', 'positionM、up：3×K ECEF 坐标 m 与单位向上向量。'),
'leo_predict_orbit': ('p：轨道及地球参数；r：基本槽采样时刻。', 'o：3×T 轨道位置 m、速度及 3×3×T 阵列姿态。'),
'leo_compute_geometry': ('p：覆盖门槛；u/o：用户与卫星轨道结构。', 'g：K×T 距离、仰角、可见性及 3×K×T 阵列方向。'),
'leo_array_response': ('p：UPA 参数；direction：3×N 阵列坐标系单位方向。', 'a：Na×N 单位范数复阵列响应。'),
'leo_build_codebook': ('p：固定候选网格、量化位数、码本大小。', 'cb：Na×NB 合法复码字及对应方向元数据。'),
'leo_select_codebook': ('p：目标码字数；cb：量化去重后的固定候选码本。', 'cb：在用户产生前离线冻结的子码本。'),
'leo_check_codebook_coverage': ('p：扫描验证网格、覆盖门槛；cb：实际有限码本。', 'c：抽样最优增益、空洞比例；不是连续扫描域证明。'),
'leo_assign_beams': ('p/r/g/cb：参数、固定资源、预测几何、冻结码本。', 'b：K×M 可用掩码/预指派码字，以及 K×NB×T 实际增益。'),
'leo_large_scale_channel': ('p：链路及噪声参数；g：距离与几何。', 'c：K×T 单阵元功率增益 beta、噪声功率 W。'),
'leo_generate_fading': ('p/g/b/c：参数、几何、波束、大尺度信道。', 'f：复 Rician 样本、功率 Z、Na×K×T 瞬时复信道。'),
'leo_link_coefficients': ('p/r/b/c：固定功率、资源、预指派码字、信道。', 'link：K×T 信号系数与 K×NB×T 用户—波束干扰系数 W。'),
'leo_example_selection': ('p/r/b：人数上限、资源与可用/波束约束。', 'x：K×M 合法轮换示例，非公平优化结果。'),
'leo_compute_sinr': ('p/r/b/c/f/link/cb：完整物理结构；x：K×M 合法二元日程。', 'out：K×T 瞬时 SINR（线性及 dB）、激活掩码、信号/干扰功率 W。'),
'leo_rician_power_cdf': ('z：非负归一化功率；kappa：线性 Rician 因子。', 'cdfValue/cdfUpper：CDF 近似及带截断余项的上界。'),
'leo_rician_power_quantile': ('probability：尾部概率；kappa：线性 Rician 因子。', 'zeta：保守非负功率低分位，不含 dB 单位。'),
'leo_prepare_design_service': ('p/r/b/c/link：联合风险、资源、候选及固定链路系数。', 'd：所有候选基本槽的风险/分位值、固定设计功率 W。'),
'leo_build_hard_constraints': ('p/r/b：人数/固定块/波束可用性。', 'hard：x(:) 的稀疏 A/rhs、上下界、整数索引；列优先排列。'),
'leo_form_problem': ('p/r/b/design：参数、资源、波束、设计服务系数。', 'problem：原始两阶段问题回调、数据与可服务性预检；尚未求解。'),
'leo_form_stage2': ('data：原问题数据；x0：K×M 已有合法日程。', 'stage：以 x0 原始公平为固定门槛的 O4 模板。'),
'leo_problem_objective': ('z：完整优化向量；data：原模型；stage：1 或 2。', 'value：最小化形式的负公平/负归一化总服务。'),
'leo_problem_nonlcon': ('z/data：优化向量与原模型；stage：1/2；s0：阶段 2 门槛。', 'c/ceq：归一化非线性约束，c<=0；无额外等式。'),
'leo_check_problem_point': ('stage：问题模板；z：候选向量；tolerance：检查容差。', 'report：边界、整数、线性及 QoS 约束的违反量/可行性。'),
'leo_precheck_positive_fairness': ('data：所有用户需求、正服务机会与硬约束。', 'check：最大流值、见证日程、正公平可能性与不可服务用户。'),
'leo_evaluate_service': ('data：固定设计模型；x：K×M 日程；可选 requireFeasibleBinary。', 'service：逐槽/逐块/逐用户 bit、最差需求比、公平和净总服务。'),
'leo_evaluate_quadratic_service': ('data：模型；q：aBits/bBits；x：K×M 日程；可选二元校验。', 'result：二次服务 bit 及归一化公平，保留负下界。'),
'leo_schedule_interference': ('data：设计信道；x：K×M 合法二元日程。', 'I：K×T 干扰功率 W，含未选用户的反事实接收干扰。'),
'leo_interference_limits': ('data：完整物理候选域及每流固定功率。', 'limits：条件选中用户的 K×T 合法干扰上限 W 与事件掩码。'),
'leo_rate_and_derivatives': ('S/N/I：信号、噪声、干扰功率 W；B：带宽 Hz。', 'rate/first/second：bit/s 及对 W 的一、二阶导数。'),
'leo_tangent_lower': ('S/N：固定功率 W；B：Hz；referenceW：合法切点 W。', 'line：alphaBps、omegaBpsPerW 与切点速率；ell=alpha-omega*I。'),
'leo_chord_upper': ('S/N：固定功率 W；B：Hz；a/b：干扰区间端点 W。', 'line：弦系数、minimax 切点、最大误差 bit/s 与曲率界。'),
'leo_build_service_surrogates': ('problem：原问题；mode：minimax/zero/current_schedule；x0：仅相切模式需要。', 'proxy：切线/弦线、二次 a/b、合法区间、服务误差 bit 及公平误差界。'),
'leo_assemble_quadratic_service': ('data：模型；alphaBps/omegaBpsPerW：K×T 仿射速率系数。', 'q：K×M aBits、K×K×M 有向 bBits，逐基本槽精确累加。'),
'leo_evaluate_service_bounds': ('problem/proxy：原模型与同一模型代理；x：合法日程。', 'result：下界、原始、上界服务及夹逼检查。'),
'leo_check_surrogate_groups': ('problem/proxy：原模型及代理；maxGroupsPerResource：枚举保护上限。', 'report：各资源全部合法组的夹逼/误差检查及覆盖组合规模。'),
'leo_method_options': ('overrides：可选算法参数覆盖结构。', 'o：校验后的价格、SB、修复、预算、内层求解器和切点设置。'),
'leo_price_weights': ('data：需求及 Dref；lambda：K×1 非负价格；phase/s0：阶段和门槛。', 'weights：K×1 服务权重（1/bit）；sAux：公平辅助解或固定门槛。'),
'leo_update_prices': ('lambda：价格；lowerUserBits：价格日程下界 bit；q：需求 bit；sAux/step。', 'lambdaNext：非负投影后的新价格，负服务下界不截断。'),
'leo_build_resource_qubo': ('data/lower：模型及下界；m：块号；weights：K×1；options：罚权/松弛选项。', 'qubo：局部用户索引、A/B、对称/上三角 QUBO、常数与松弛位。'),
'leo_qubo_to_ising': ('qubo：E=C+z\'Qsym z 的对称二次编码。', 'ising：J/h/constant，E=C\'+h\'sigma+sigma\'J sigma/2。'),
'leo_encode_group_bits': ('qubo：局部编码；x：nUsers×1 合法用户组。', 'z：用户位及重新编码的容量松弛位；二元列向量。'),
'leo_ballistic_sb': ('ising：J/h；options：轨迹/积分参数；seeds：位种子；budget：软时间上限。', 'result：每轨迹最佳离散位/能量、积分步数、尺度和超时状态。'),
'leo_repair_group': ('qubo：收益/冲突/容量信息；x：可能冲突的局部用户位。', 'x：通过删除最小收益损失用户得到的合法组。'),
'leo_polish_group': ('qubo：固定二次目标；x：合法局部组；maxMoves：最大改进动作数。', 'x：可行 add/drop/swap 改进后的组，代理收益不下降。'),
'leo_solve_resource_sb': ('data/lower/m/weights：内层 L4；oldGroup：K×1；options/budget：搜索配置。', 'result：合法 K×1 组、代理分数、SB 步数与修复计数；保留旧组。'),
'leo_budget_expired': ('budget：含 tic 句柄 timer 和秒数 seconds；[] 表示不设限。', 'expired：逻辑标量，已达软时间上限。'),
'leo_initial_schedules': ('problem：原模型；provided：可选已有日程；options/budget：随机种子及预算。', 'initial：共同可行初始化中按原始公平/吞吐最好的日程与各起点成绩。'),
'leo_recover_schedule': ('problem/x：原模型与起点；phase/s0：验收规则；options/roundIndex/budget。', 'result：原始服务严格改善的完整日程、服务及动作计数。'),
'leo_service_is_better': ('candidate/incumbent：原始服务；phase：fairness/throughput；s0：固定门槛。', 'better：是否可替换保存日程；阶段 2 严格满足每用户门槛。'),
'leo_prepare_upper_bounds': ('data：完整物理域、用户—波束干扰及固定资源。', 'cache：K×M×L 按组基数的原始服务上界 bit。'),
'leo_original_upper_bound': ('data/cache：完整模型和 UB1 缓存；lambda：非负价格；phase/s0。', 'bound：原始公平或归一化吞吐有效上界、资源项与价格。'),
'leo_run_price_phase': ('problem/proxy/cache：模型、固定代理、有效界；phase/start/options/budget。', 'result：阶段保存日程、价格轨迹、相切误差、独立上界和停止状态。'),
'leo_solve_schedule': ('problem：原问题；proxy：可选已有代理；options：方法参数；initialSchedule：可选日程。', 'result：两阶段日程、原始服务、严格公平门槛、有效差距与运行记录。'),
'leo_exhaustive_options': ('overrides：可选规模、内存、批次及时间上限。', 'options：完整穷举的保护配置，不自动缩小物理问题。'),
'leo_exhaustive_size': ('data：每个资源的候选、波束归属与人数上限。', 'estimate：合法组数、完整组合数、log10 规模与双精度精确计数标志。'),
'leo_enumerate_resource_groups': ('data：模型；m：块号；maxGroups：合法组数量保护阈值。', 'groups：K×G 合法二元组，包括空组。'),
'leo_resource_group_services': ('data：原始设计模型；m：块号；groups：K×G 合法组。', 'bits：K×G 原始块服务 bit，支持批量穷举评价。'),
'leo_exhaustive_search': ('problem：原问题；overrides：可选穷举预算。', 'result：最优/超限/超时状态、已访问数量、最好合法日程及原始服务。'),
'leo_compare_schedules': ('problem：同一模型；schedules：日程 cell；names：对应标签 cell。', 'rows：各日程原始公平、总服务 bit 和每用户服务结构体表。'),
'run_leo_sinr': ('p：可选完整参数；默认 32 波束、8 并发、50 ms 固定块。', 'model：物理模型、原问题、代理及启用时的 method/exhaustive 求解结果。'),
'run_leo_method_demo': ('p：可选自定义参数；省略时 8 用户/3 块并启用穷举。', 'model/comparison：两阶段方法、后置穷举及同原始服务口径的比较。'),
'run_leo_exhaustive_demo': ('p：可选自定义参数；省略时 8 用户/3 块。', 'model/comparison：原始完整穷举及轮换/预检见证对比。'),
'run_leo_surrogate_demo': ('无；使用固定 8 用户/3 块穷举例。', 'model/comparison：minimax 与当前点相切的服务夹逼/误差验证。'),
}

def main():
    files = sorted((ROOT/'matlab').glob('*.m'))
    records = []
    for path in files:
        text = path.read_text()
        if not text.startswith('function '):
            continue
        name = path.stem
        if name.startswith('test_'):
            IO[name] = ('无；构造独立数值基准及边界算例。', '无返回值；失败时抛出断言，成功时打印检查组数。')
        if name in IO and '% 接口标注：' not in text:
            lines = text.splitlines()
            inp, out = IO[name]
            lines[2:2] = ['% 接口标注：', '% 输入：'+inp, '% 输出：'+out]
            text = '\n'.join(lines)+'\n'
            path.write_text(text)
        header = []
        for line in text.splitlines()[1:]:
            if not line.startswith('%'): break
            header.append(line.lstrip('%').strip())
        assert any('输入' in x for x in header), f'Missing input annotation: {name}'
        assert any('输出' in x for x in header), f'Missing output annotation: {name}'
        purpose = re.sub(r'^[A-Z_]+\s*', '', header[0])
        records.append((name, text.splitlines()[0], purpose, header, text))
    names = {r[0] for r in records}
    doc = ['# 函数索引与调用关系', '',
        '所有公开 `.m` 函数均含中文输入、输出说明。MATLAB 中执行 `help 函数名` 可直接查看。', '',
        '维度约定：K 为用户数，M 为固定时间块数，T 为基本槽数，NB=32 为码本大小，L=8 为最大并发人数。',
        '`x` 通常为 K×M；资源内层的局部 `x` 为 nUsers×1。功率 W、带宽 Hz、时间 s、服务 bit；dB 字段单独标明。',
        '`problem.data` 是固定的原始设计模型；`proxy.lower/upper` 含 aBits(K×M)、bBits(K×K×M)。',
        '全周期验收调用 `leo_evaluate_service`；瞬时随机信道 SINR 不参与统计 CSI 调度的原始设计评分。', '',
        '主调用链：`run_leo_sinr → leo_form_problem → leo_build_service_surrogates → leo_solve_schedule → leo_run_price_phase → leo_solve_resource`。',
        '对比链：`run_leo_benchmarks → leo_benchmark_case → leo_run_benchmark_method → 各基线 → leo_export_benchmark`。', '',
        '绘图链：`run_leo_plot_results → leo_collect_plot_data → leo_build_plot_specs → leo_render_plot_specs`；图表与迭代口径见 PLOTS.md。', '',
        '| 函数 | 作用 / 方案位置 |', '|---|---|']
    contents = ['% LEO 固定块 QoS：建模、两阶段拉格朗日 SB、原始穷举与统一实验。',
        '% 完整公式/输入输出/调用关系见仓库 FUNCTION_GUIDE.md。', '%']
    for name, sig, purpose, header, text in records:
        doc.append(f'| [{name}](matlab/{name}.m) | {purpose.replace("|", "/")} |')
        contents.append(f'%   {name:<34} - {purpose}')
    for name, sig, purpose, header, text in records:
        called = sorted(n for n in names if n != name and re.search(r'\b'+n+r'\s*\(', text))
        callers = sorted(r[0] for r in records if r[0] != name and re.search(r'\b'+name+r'\s*\(', r[4]))
        doc.extend(['', f'## {name}', '', f'```matlab\n{sig}\n```', '', '\n'.join(header[1:]), '',
            '直接调用：'+(', '.join(f'`{n}`' for n in called) or '基础 MATLAB 运算')+'。',
            '调用入口：'+(', '.join(f'`{n}`' for n in callers) or '用户直接调用 / 独立测试')+'。'])
    (ROOT/'FUNCTION_GUIDE.md').write_text('\n'.join(doc)+'\n')
    (ROOT/'matlab'/'Contents.m').write_text('\n'.join(contents)+'\n')
    print(f'Annotated and indexed {len(records)} public MATLAB functions.')

if __name__ == '__main__':
    main()
