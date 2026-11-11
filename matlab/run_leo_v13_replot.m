function files = run_leo_v13_replot(directory,render)
%RUN_LEO_V13_REPLOT 读取已有V13日程重画清晰方法名，不重新搜索或重算上界。
if nargin<2, render=true; end
report=leo_v12_load_report(directory);
assert(strcmp(report.releaseTag,'V13'),'Expected a saved V13 benchmark.');
spec=leo_build_v12_specs(report,leo_v12_trace_data(report));
fid=fopen(fullfile(directory,'v13_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(spec)); fclose(fid);
files={}; if render, files=leo_render_plot_specs(spec,directory); end
[~,extra]=run_leo_v12_diagnostics(report,directory,render); files=[files,extra];
leo_write_struct_csv(fullfile(directory,'stopping_summary.csv'),leo_stopping_rows(report));
end
