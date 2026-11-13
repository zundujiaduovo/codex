function [rows,files]=run_leo_v14_targets(report,directory,render)
% 仅第一阶段，统一绝对公平目标；未达到保持NaN，不用预算替代。
if nargin<3, render=true; end
targets=[2.50,2.60,2.65,2.70]; trace=leo_v12_trace_data(report); rows=struct([]);
methods=report.options.methods; labels=cellfun(@leo_method_name,methods,'UniformOutput',false);
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    progress=trace.progress(strcmp({trace.progress.method},r.method) & [trace.progress.seed]==r.seed & [trace.progress.phase]<=1);
    for target=targets
        at=find([progress.fairness]>=target,1); seconds=NaN; if ~isempty(at), seconds=progress(at).seconds; end
        rows=leo_append_struct(rows,struct('method',leo_method_name(r.method),'seed',r.seed,'fairnessTarget',target, ...
            'reached',~isempty(at),'seconds',seconds,'scope','First observed stage-1 original-service attainment, including common setup.'));
    end
end
leo_write_struct_csv(fullfile(directory,'v17_fixed_fairness_targets.csv'),rows);
p=leo_v14_panel('Stage 1: time to identical original fairness targets','Method','Seconds','categorical_line',labels);
for target=targets
    y=NaN(1,numel(methods));
    for j=1:numel(methods)
        at=find(strcmp({rows.method},labels{j}) & [rows.seed]==report.options.seeds(1) & [rows.fairnessTarget]==target,1);
        if ~isempty(at), y(j)=rows(at).seconds; end
    end
    p=leo_v14_series(p,sprintf('s >= %.2f',target),1:numel(methods),y);
end
spec=struct('name','v17_fixed_fairness_targets','title','V14 original fairness targets | missing attainment remains N/A','rows',1,'cols',1,'panels',p);
files=leo_v14_save_specs(spec,directory,'v17_target_specs',render);
end
