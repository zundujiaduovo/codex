# V12 独立执行证据

2026-11-11，Octave 9.4.0 / GLPK，场景和单个搜索种子 71669974；每方法 120 秒，公平证书 180 秒、各条件吞吐证书 30 秒，独立衰落验证 1000 个周期。
V12 目标是未封顶最大最差用户累计比例，再保持实际阶段一公平提高总服务。与 V10/V11 目标不同。

`search_and_certificate.log` 摘录完整搜索与证书阶段；`summary_and_export_audit.log` 为复用已保存配对后、最终导出格式的汇总与独立原式复核。
`regression.log`、`regression_additional.log` 记录目标迁移后的回归；`main_smoke.log` 是较短流程冒烟，不作为 120 秒性能成绩。
`export_and_protocol_smoke.log` 检查两阶段导出和协议不匹配拒绝；`release_check.log` 检查解压后的纯源码包。
完整算法 MAT 保存在运行目录，仓库保留可独立复核的冻结原模型、两阶段 CSV 日程/用户服务、实际检查点、协议、证书状态和共享绘图规格。

从源码根目录复核，无需重新搜索：

```matlab
addpath('matlab');
run_leo_v12_verify_exports(fullfile('validation','v12_uncapped_lexicographic_octave'))
```

`figures/` 按同一 JSON 规格用 Python/Matplotlib 渲染，未生成 MATLAB FIG，也未实测 Windows MATLAB 桌面。
公平证书区间 [1.811163176,1.820346506]，相对差距约 0.50448%，到时停止，未达到预设容差。SB 此次主公平指标低于 Tabu 和 Local。
详细解释见仓库根目录 V12_VALIDATION.md。
