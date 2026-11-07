% 从已保存的算法结果直接画对比图，不重新求解，也不依赖 leo_* 函数。
if ~exist('comparisonRoot','var') || isempty(comparisonRoot)
    comparisonRoot = fileparts(mfilename('fullpath'));
end
comparisonDirectory = fullfile(comparisonRoot,'results','comparison');
comparisonSaved = load(fullfile(comparisonDirectory,'raw_benchmark.mat'));
report = comparisonSaved.report;
comparisonGood = strcmp({report.records.status},'completed');
comparisonRows = report.records(comparisonGood);
assert(~isempty(comparisonRows),'备份中没有成功的算法结果。');
assert(numel(unique([comparisonRows.seed]))==1, ...
    '此恢复入口针对单种子快速对比；多种子报告请使用 run_leo_comparison。');
comparisonLabels = {comparisonRows.method};
comparisonPeriod = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
comparisonValues = [[comparisonRows.fairness];100*[comparisonRows.qosSatisfactionRate]; ...
    [comparisonRows.totalBits]/(1e6*comparisonPeriod);[comparisonRows.endToEndSeconds]];
comparisonTitles = {'Certified minimum QoS ratio','Users meeting certified full QoS', ...
    'Certified sum rate','Accounted end-to-end runtime'};
comparisonUnits = {'Ratio','Percent','Mbps','Seconds'};
fig = [];
if ~exist('comparisonRender','var') || comparisonRender
    fig = figure('Color','w','Name','Recovered method comparison','Position',[60,60,1300,760]);
    for comparisonPanel = 1:4
        subplot(2,2,comparisonPanel);
        bar(comparisonValues(comparisonPanel,:));
        set(gca,'XTick',1:numel(comparisonRows),'XTickLabel',comparisonLabels, ...
            'XTickLabelRotation',20,'TickLabelInterpreter','none');
        title(comparisonTitles{comparisonPanel}); ylabel(comparisonUnits{comparisonPanel}); grid on;
    end
    print(fig,fullfile(comparisonDirectory,'comparison_recovered.png'),'-dpng','-r160');
end
fprintf('Recovered %d methods from raw_benchmark.mat; no algorithms re-run.\n',numel(comparisonRows));
