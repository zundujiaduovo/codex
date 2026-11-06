function files = leo_plot_benchmark(report,directory)
%LEO_PLOT_BENCHMARK 完整对比图入口：迭代、收敛、性能、资源及代理诊断共 18 图。
% 输入：报告或 plotData、输出目录；输出：PNG/PDF/FIG 路径，另存数值输入。
[~,specs] = leo_export_plot_data(report,directory);
files = leo_render_plot_specs(specs,directory);
end
