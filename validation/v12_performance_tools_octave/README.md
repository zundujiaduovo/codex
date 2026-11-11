# V12 性能验证工具：执行证据

本目录补充原 V12 云端实验；原三方法日程和成绩未重跑或改写。与用户 Windows 运行的搜索轨迹分开解释。

- `greedy/`：原式贪婪增补后的四方法 CSV、两阶段日程、迭代和工作量。原模型与原公平证书从前一批发布数据逐字节复用。
- `proxy_control/`：16 个最多 12 候选用户的精确块/价格案例、16 组 SB/Local 配对调用、实际权重、参考日程、选中组和非参考点代理探针。物理模型为 `../greedy/original_model.mat`。
- `scaling_smoke/`：K=4/8、M=3、一个搜索种子的八次流程验证；完整默认规模实验未执行。配置和结果保存在 `scaling.mat`。
- 日志和 `execution.json`：回归、缓存/协议检查、原式复核、源包解压测试及来源信息。

从仓库根目录复核四方法两阶段的八份日程：

```matlab
addpath('matlab');
run_leo_v12_verify_exports(fullfile('validation','v12_performance_tools_octave','greedy'))
```

源包只包含源码和文档。图使用同一 MATLAB JSON 规格由 Python 渲染；Windows MATLAB 桌面未实机测试。方法、计算量范围和诊断限制见根目录 `V12_PERFORMANCE_VALIDATION.md`。
