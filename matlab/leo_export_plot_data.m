function [plotData,specs] = leo_export_plot_data(source,directory)
%LEO_EXPORT_PLOT_DATA 导出绘图输入、迭代/时间/价格/能量 CSV 和跨渲染器 JSON。
% 输入：对比报告或已收集 plotData、输出目录；输出：纯数值 plotData 与图形规格 specs。
% 无图形后端也能完成；后处理耗时不计入算法运行时间。
if isfield(source,'schemaVersion'), plotData = source;
else, plotData = leo_collect_plot_data(source); end
specs = leo_build_plot_specs(plotData);
if ~exist(directory,'dir'), mkdir(directory); end
tables = {'counts','events','progress','prices','energy'};
files = {'iterations.csv','iteration_history.csv','convergence.csv','price_history.csv','sb_energy.csv'};
for j = 1:numel(tables)
    leo_write_struct_csv(fullfile(directory,files{j}),plotData.(tables{j}));
end
save(fullfile(directory,'plot_data.mat'),'plotData','-v7');
json = jsonencode(specs); % 非有限数导出 null，渲染时保留为缺失值。
fid = fopen(fullfile(directory,'plot_specs.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',json);
end
