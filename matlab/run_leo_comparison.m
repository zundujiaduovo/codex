function [report,fig] = run_leo_comparison(outputDirectory,overrides,render)
%RUN_LEO_COMPARISON 同场景比较全部 12 项方法/消融，输出完整图组。
% 默认每方法 12 秒软预算、三个算法种子；可覆盖 leo_benchmark_options。
if nargin<1, outputDirectory = fullfile('results','comparison'); end
if nargin<2, overrides = struct(); end
if nargin<3, render = true; end
p = leo_default_parameters();
if isfield(overrides,'qosTargetBits')
    p.system.qosTargetBits = overrides.qosTargetBits;
    overrides = rmfield(overrides,'qosTargetBits');
end
defaults = leo_benchmark_options();
names = fieldnames(overrides);
for j = 1:numel(names), defaults.(names{j}) = overrides.(names{j}); end
defaults.outputDirectory = outputDirectory;
defaults.exhaustive = false; defaults.makePlots = false;
report = run_leo_benchmarks(p,defaults);
% 日程固定后，用同一批新衰落比较实际平均吞吐；不以验证样本选择日程。
for j = 1:numel(report.records)
    report.records(j).sampleMeanTotalBits = NaN;
    report.records(j).sampleMeanUserQosRate = NaN;
    report.records(j).sampleJointSuccessRate = NaN;
    report.records(j).jainFairness = NaN;
    if ~strcmp(report.records(j).status,'completed'), continue; end
    service = report.solutions{j}.service.userBits;
    if sum(service.^2)>0
        report.records(j).jainFairness = sum(service)^2/(numel(service)*sum(service.^2));
    end
    fprintf('Independent fading validation: %s, seed %d\n',report.records(j).method,report.records(j).seed);
    try
        mc = leo_sample_period_service(report.problemData,report.solutions{j}.x, ...
            report.parameters.channel.ricianK,1000,20261108);
        report.records(j).sampleMeanTotalBits = mc.meanTotalBits;
        report.records(j).sampleMeanUserQosRate = mc.meanUserQosRate;
        report.records(j).sampleJointSuccessRate = mc.jointSuccessRate;
        report.solutions{j}.sampleValidation = mc;
    catch err
        warning('leo:sampleValidation','Independent fading validation failed: %s',err.message);
    end
end
leo_export_benchmark(report,outputDirectory);
[fig,~] = leo_plot_method_comparison(report,outputDirectory,render);
if render
    leo_plot_extra_metrics(report,outputDirectory);
    try
        run_leo_plot_results(report,outputDirectory,true);
        fprintf('18 additional figures saved in %s\n',outputDirectory);
    catch err
        warning('leo:plotUnavailable','Detailed figures could not all be rendered: %s',err.message);
    end
end
fprintf('Comparison results: %s\n',outputDirectory);
fprintf('Demand per user: %.3f Mbit (first user); fairness and full-QoS rate may saturate.\n', ...
    report.problemData.qosTargetBits(1)/1e6);
end

function fig = leo_plot_extra_metrics(report,directory)
%LEO_PLOT_EXTRA_METRICS Jain 公平、平均完成率与独立衰落 QoS 对比。
methods = report.options.methods; count = numel(methods); values = NaN(count,4);
fields = {'jainFairness','averageCompletion','sampleMeanUserQosRate','sampleJointSuccessRate'};
for j = 1:count
    rows = report.records(strcmp({report.records.method},methods{j}) & strcmp({report.records.status},'completed'));
    for k = 1:4
        if isempty(rows), continue; end
        a = [rows.(fields{k})]; a = a(isfinite(a));
        if ~isempty(a), values(j,k) = median(a); end
    end
end
titles = {'Jain fairness of certified service','Average certified demand completion', ...
    'Mean user QoS rate under fading','Joint all-user QoS success under fading'};
fig = figure('Visible','on','Color','w','Name','Additional QoS metrics','Position',[40,40,1500,800]);
for k = 1:4
    subplot(2,2,k); bar(values(:,k));
    set(gca,'XTick',1:count,'XTickLabel',methods,'XTickLabelRotation',35, ...
        'TickLabelInterpreter','none');
    title(titles{k}); ylabel('Ratio'); ylim([0,1.05]); grid on;
    for j = find(~isfinite(values(:,k))).'
        text(j,.03,'N/A','Rotation',90,'HorizontalAlignment','left');
    end
end
if ~exist(directory,'dir'), mkdir(directory); end
print(fig,fullfile(directory,'additional_qos_metrics.png'),'-dpng','-r160');
if exist('savefig','file')~=0, savefig(fig,fullfile(directory,'additional_qos_metrics.fig')); end
end
