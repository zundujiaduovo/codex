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
comparisonLabels = report.options.methods;
comparisonPeriod = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
comparisonValues = NaN(4,numel(comparisonLabels));
for comparisonMethod = 1:numel(comparisonLabels)
    comparisonSubset = comparisonRows(strcmp({comparisonRows.method},comparisonLabels{comparisonMethod}));
    if isempty(comparisonSubset), continue; end
    comparisonValues(:,comparisonMethod) = [median([comparisonSubset.fairness]); ...
        100*median([comparisonSubset.qosSatisfactionRate]); ...
        median([comparisonSubset.totalBits])/(1e6*comparisonPeriod); ...
        median([comparisonSubset.endToEndSeconds])];
end
comparisonTitles = {'Certified minimum QoS ratio','Users meeting certified full QoS', ...
    'Certified sum rate','Accounted end-to-end runtime'};
comparisonUnits = {'Ratio','Percent','Mbps','Seconds'};
fig = [];
if ~exist('comparisonRender','var') || comparisonRender
    fig = figure('Color','w','Name','Recovered method comparison','Position',[60,60,1300,760]);
    for comparisonPanel = 1:4
        subplot(2,2,comparisonPanel);
        bar(comparisonValues(comparisonPanel,:));
        set(gca,'XTick',1:numel(comparisonLabels),'XTickLabel',comparisonLabels, ...
            'XTickLabelRotation',20,'TickLabelInterpreter','none');
        title(comparisonTitles{comparisonPanel}); ylabel(comparisonUnits{comparisonPanel}); grid on;
    end
    print(fig,fullfile(comparisonDirectory,'comparison_recovered.png'),'-dpng','-r160');
end
fprintf('Recovered %d completed runs from raw_benchmark.mat; no algorithms re-run.\n',numel(comparisonRows));
