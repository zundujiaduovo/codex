function [metrics,files] = run_leo_performance_metrics(source,directory,options,render)
%RUN_LEO_PERFORMANCE_METRICS 读取现有日志，不重跑算法；全方法同一套质量/时间指标。
if nargin<3, options=struct(); end
if nargin<4, render=true; end
base=pwd;
if ischar(source) || (isstring(source) && isscalar(source))
    source=char(source); base=fileparts(source); loaded=load(source);
    if isfield(loaded,'report'), source=loaded.report;
    elseif isfield(loaded,'plotData'), source=loaded.plotData;
    else, error('MAT 文件中没有 report 或 plotData。'); end
end
if nargin<2 || isempty(directory), directory=fullfile(base,'performance_metrics'); end
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
if ~exist(directory,'dir'), mkdir(directory); end
if isfield(source,'schemaVersion'), data=source; else, data=leo_collect_plot_data(source); end
metrics=leo_performance_metrics(data,options);
leo_write_struct_csv(fullfile(directory,'performance_summary.csv'),metrics.summary);
leo_write_struct_csv(fullfile(directory,'time_to_quality.csv'),metrics.targets);
leo_write_struct_csv(fullfile(directory,'quality_at_deadlines.csv'),metrics.deadlines);
save(fullfile(directory,'performance_metrics.mat'),'metrics','-v7');
specs=leo_build_performance_specs(metrics,data.methods,data.representativeSeed);
fid=fopen(fullfile(directory,'performance_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(specs)); fclose(fid);
files={}; if render, files=leo_render_plot_specs(specs,directory); end
fprintf('Quality/time metrics saved in %s; no algorithm rerun.\n',directory);
end
