function [report,fig] = run_leo_comparison(outputDirectory,overrides,render)
%RUN_LEO_COMPARISON 同场景同预算比较五种方法，直接显示并保存六项对比图。
% 默认每方法 60 秒软预算、一个共同算法种子；可覆盖 leo_benchmark_options。
if nargin<1, outputDirectory = fullfile('results','comparison'); end
if nargin<2, overrides = struct(); end
if nargin<3, render = true; end
defaults.methods = {'initial','original_greedy','original_tabu','price_sb','price_local'};
defaults.seeds = 20261105; defaults.budgetSeconds = 60;
names = fieldnames(overrides);
for j = 1:numel(names), defaults.(names{j}) = overrides.(names{j}); end
defaults.outputDirectory = outputDirectory;
defaults.exhaustive = false; defaults.makePlots = false;
report = run_leo_benchmarks('default',defaults);
% 日程固定后，用同一批新衰落比较实际平均吞吐；不以验证样本选择日程。
for j = 1:numel(report.records)
    report.records(j).sampleMeanTotalBits = NaN;
    report.records(j).sampleMeanUserQosRate = NaN;
    if ~strcmp(report.records(j).status,'completed'), continue; end
    fprintf('Independent fading validation: %s, seed %d\n',report.records(j).method,report.records(j).seed);
    mc = leo_sample_period_service(report.problemData,report.solutions{j}.x, ...
        report.parameters.channel.ricianK,1000,20261108);
    report.records(j).sampleMeanTotalBits = mc.meanTotalBits;
    report.records(j).sampleMeanUserQosRate = mc.meanUserQosRate;
    report.solutions{j}.sampleValidation = mc;
end
leo_export_benchmark(report,outputDirectory);
[fig,~] = leo_plot_method_comparison(report,outputDirectory,render);
fprintf('Comparison results: %s\n',outputDirectory);
fprintf('Default demand: 1 Mbit/user. Fairness and full-QoS rate may saturate; compare sum rates too.\n');
end
