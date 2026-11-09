% 从已保存的算法结果直接画对比图，不重新求解，也不依赖 leo_* 函数。
if ~exist('comparisonRoot','var') || isempty(comparisonRoot)
    comparisonRoot = fileparts(mfilename('fullpath'));
end
comparisonBase = fullfile(comparisonRoot,'results','comparison');
if exist('recoveryDirectory','var') && ~isempty(recoveryDirectory)
    comparisonDirectory = recoveryDirectory;
else
    comparisonCandidates = dir(fullfile(comparisonBase,'seed_*','raw_benchmark.mat'));
    if numel(comparisonCandidates)==1
        comparisonDirectory = comparisonCandidates(1).folder;
    elseif numel(comparisonCandidates)>1
        [comparisonFile,comparisonDirectory] = uigetfile(fullfile(comparisonBase,'*.mat'), ...
            '选择要恢复的种子目录中的 raw_benchmark.mat');
        if isequal(comparisonFile,0), error('leo:cancelled','未选择备份文件。'); end
        assert(strcmp(comparisonFile,'raw_benchmark.mat'),'请选择 raw_benchmark.mat。');
    else
        comparisonDirectory = comparisonBase; % 兼容 V3 旧目录
    end
end
comparisonSaved = load(fullfile(comparisonDirectory,'raw_benchmark.mat'));
report = comparisonSaved.report;
comparisonGood = strcmp({report.records.status},'completed');
comparisonRows = report.records(comparisonGood);
assert(~isempty(comparisonRows),'备份中没有成功的算法结果。');
comparisonLabels = report.options.methods;
comparisonPeriod = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
comparisonValues = NaN(4,numel(comparisonLabels));
comparisonStrict=isfield(report.problemData,'requireFullQos') && report.problemData.requireFullQos;
for comparisonMethod = 1:numel(comparisonLabels)
    comparisonSubset = comparisonRows(strcmp({comparisonRows.method},comparisonLabels{comparisonMethod}));
    if isempty(comparisonSubset), continue; end
    comparisonTotal=median([comparisonSubset.totalBits]);
    if comparisonStrict
        comparisonFeasible=comparisonSubset([comparisonSubset.fullQosFeasible]);
        comparisonTotal=NaN;
        if ~isempty(comparisonFeasible), comparisonTotal=median([comparisonFeasible.totalBits]); end
    end
    comparisonValues(:,comparisonMethod) = [median([comparisonSubset.fairness]); ...
        100*median([comparisonSubset.qosSatisfactionRate]); ...
        comparisonTotal/(1e6*comparisonPeriod); ...
        median([comparisonSubset.endToEndSeconds])];
end
comparisonTitles = {'Certified minimum QoS ratio','Users meeting certified full QoS', ...
    'Certified sum rate (V5: full QoS only)','Accounted end-to-end runtime'};
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
