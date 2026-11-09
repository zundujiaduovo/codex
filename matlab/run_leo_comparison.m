function [report,fig] = run_leo_comparison(outputDirectory,overrides,render)
%RUN_LEO_COMPARISON 同场景比较全部 16 项方法/消融，输出完整图组。
% 默认固定参考用户位置，采用论文部分参数；生成一个随机基础种子供所有方法共享。
if nargin<1, outputDirectory = fullfile('results','comparison'); end
if nargin<2, overrides = struct(); end
if nargin<3, render = true; end
% 图形 print 使用绝对路径，避免当前目录与 print 内部路径解析不一致。
if isempty(regexp(outputDirectory,'^([A-Za-z]:[\\/]|[\\/])','once'))
    outputDirectory = fullfile(pwd,outputDirectory);
end
theoryOptions = struct();
if isfield(overrides,'theoryOptions')
    theoryOptions = overrides.theoryOptions;
    overrides = rmfield(overrides,'theoryOptions');
end
isolateRun = true;
if isfield(overrides,'isolateRun')
    isolateRun = overrides.isolateRun;
    assert(isscalar(isolateRun) && (isolateRun==0 || isolateRun==1));
    overrides = rmfield(overrides,'isolateRun');
end
validationSamples = 100;
if isfield(overrides,'validationSamples')
    validationSamples = overrides.validationSamples;
    overrides = rmfield(overrides,'validationSamples');
end
assert(isnumeric(validationSamples) && isscalar(validationSamples) && isfinite(validationSamples) && ...
    validationSamples>=1 && validationSamples==fix(validationSamples));
p = leo_paper_parameters();
if isfield(overrides,'seeds')
    runSeed = overrides.seeds;
    assert(isnumeric(runSeed) && isscalar(runSeed) && isfinite(runSeed) && ...
        runSeed>=0 && runSeed<=2^32-1 && runSeed==fix(runSeed),'比较入口只接受一个有效随机种子。');
else
    runSeed = leo_random_seed();
end
p.seed = runSeed;
if isfield(overrides,'usersLayout')
    p.users.layout = overrides.usersLayout;
    overrides = rmfield(overrides,'usersLayout');
end
if isolateRun
    base = fullfile(outputDirectory,sprintf('seed_%.0f',runSeed));
    outputDirectory = base; suffix = 2;
    while exist(outputDirectory,'dir')
        outputDirectory = sprintf('%s_run_%d',base,suffix); suffix = suffix+1;
    end
end
if ~exist(outputDirectory,'dir'), mkdir(outputDirectory); end
if isfield(overrides,'qosTargetBits')
    p.system.qosTargetBits = overrides.qosTargetBits;
    overrides = rmfield(overrides,'qosTargetBits');
end
defaults = leo_benchmark_options(struct('seeds',runSeed));
names = fieldnames(overrides);
for j = 1:numel(names), defaults.(names{j}) = overrides.(names{j}); end
defaults.outputDirectory = outputDirectory;
defaults.exhaustive = false; defaults.makePlots = false;
validationSeed = mod(double(runSeed)+104729,2^32);
fprintf('User layout: %s; base seed: %.0f; validation seed: %.0f\n',p.users.layout,runSeed,validationSeed);
fprintf('Output directory: %s\n',outputDirectory);
runInfo = struct('runSeed',runSeed,'validationSeed',validationSeed,'userLayout',p.users.layout, ...
    'validationSamples',validationSamples);
leo_write_struct_csv(fullfile(outputDirectory,'run_seed.csv'),runInfo);
report = run_leo_benchmarks(p,defaults);
report.runSeed = runSeed;
report.validationSeed = validationSeed;
report.validationSamples = validationSamples;
if ~all(any(report.problemData.available,2))
    warning('leo:scenarioCoverage','Scenario contains users with no available resources; fairness may be zero.');
end
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
            report.parameters.channel.ricianK,validationSamples,report.validationSeed);
        report.records(j).sampleMeanTotalBits = mc.meanTotalBits;
        report.records(j).sampleMeanUserQosRate = mc.meanUserQosRate;
        report.records(j).sampleJointSuccessRate = mc.jointSuccessRate;
        report.solutions{j}.sampleValidation = mc;
    catch err
        warning('leo:sampleValidation','Independent fading validation failed: %s',err.message);
    end
end
fprintf('Computing common theoretical bound for all-user QoS >= 100%%...\n');
try
    report.theory = leo_theory_bound(report,theoryOptions);
catch err
    warning('leo:theoryFallback','Full pricing failed, using safe cardinality bound: %s',err.message);
    report.theory = leo_theory_bound(report,struct('maxSeconds',0));
    report.theory.pricingStatus = ['Full pricing failed; UB1 used: ',err.message];
end
leo_export_theory_bound(report,outputDirectory);
fprintf('Theoretical upper bound: %.6f Mbit/period; best feasible: %.6f Mbit/period.\n', ...
    report.theory.upperBits/1e6,report.theory.lowerBits/1e6);
fprintf('Bound is for full-user QoS >= 100%% in the period certificate model; it may not be attainable.\n');
leo_export_benchmark(report,outputDirectory);
if render, leo_plot_theory_bound(report,outputDirectory); end
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
