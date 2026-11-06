function [files,plotData] = run_leo_plot_results(source,directory,render)
%RUN_LEO_PLOT_RESULTS 从已保存结果重画全部图，无需再次运行优化算法。
% 输入：benchmark.mat/plot_data.mat 路径或报告结构、输出目录；render 默认 true。
% 输出：图文件列表与数值 plotData；render=false 仅导出 CSV/MAT/JSON，适合无图形云环境。
if nargin<2, directory = fullfile('results','plots'); end
if nargin<3, render = true; end
if ischar(source)
    saved = load(source);
    if isfield(saved,'report'), source = saved.report;
    else, assert(isfield(saved,'plotData'),'输入 MAT 中需要 report 或 plotData。'); source = saved.plotData; end
end
[plotData,specs] = leo_export_plot_data(source,directory);
files = {};
if render, files = leo_render_plot_specs(specs,directory); end
end
