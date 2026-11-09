function [fig,values] = leo_plot_method_comparison(report,directory,render)
%LEO_PLOT_METHOD_COMPARISON 各方法同指标对比；成功运行中位数与 min/max。
% render=false 仅提取数值；缺失结果保持 NaN，不伪装成零。
if nargin<2, directory = fullfile('results','comparison'); end
if nargin<3, render = true; end
methods = report.options.methods; count = numel(methods); labels = methods;
known = {'initial','original_greedy','original_exchange','original_tabu','price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local','price_local_adaptive', ...
    'price_miqp','proxy_milp','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
names = {'Initial','Greedy','Exchange','Tabu','Price+SB','SB block','SB adapt','SB light','Price+Local','Local adapt', ...
    'Price+MIQP','Proxy MILP','SB zero','SB minimax','SB current','SB portfolio'};
for j = 1:count
    match = find(strcmp(methods{j},known),1);
    if ~isempty(match), labels{j} = names{match}; end
end
period = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
fields = {'fairness','qosSatisfactionRate','totalBits','nominalTotalBits','endToEndSeconds'};
strict=leo_requires_full_qos(report.problemData);
if strict && isfield(report.records,'feasibleTotalBits'), fields{3}='feasibleTotalBits'; end
sampled = isfield(report.records,'sampleMeanTotalBits');
if sampled, fields{4} = 'sampleMeanTotalBits'; end
scales = [1,100,1/(1e6*period),1/(1e6*period),1];
values.median = NaN(count,5); values.low = values.median; values.high = values.median;
values.methods = methods; values.labels = labels;
values.userRatio = NaN(report.problemData.shape(1),count);
for j = 1:count
    ids = find(strcmp({report.records.method},methods{j}) & strcmp({report.records.status},'completed'));
    for k = 1:5
        samples = arrayfun(@(r) r.(fields{k}),report.records(ids))*scales(k);
        samples = samples(isfinite(samples));
        if isempty(samples), continue; end
        values.median(j,k) = median(samples); values.low(j,k) = min(samples); values.high(j,k) = max(samples);
    end
    first = ids([report.records(ids).seed]==report.options.seeds(1));
    if ~isempty(first), values.userRatio(:,j) = report.solutions{first(1)}.service.demandRatio; end
end
fig = [];
if ~render, return; end
fig = figure('Visible','on','Color','w','Name','LEO method comparison','Position',[40,40,1700,900]);
annotation(fig,'textbox',[0,.965,1,.035],'String',sprintf( ...
    '%d users | max %d concurrent | %.2f Mbit/user | %.1f GHz | Rician %.1f dB | %.0f s/method | seed %.0f', ...
    report.problemData.shape(1),report.problemData.maxStreams,report.problemData.qosTargetBits(1)/1e6, ...
    report.parameters.system.carrierHz/1e9,report.parameters.channel.ricianKDb, ...
    report.options.budgetSeconds,report.options.seeds(1)), ...
    'EdgeColor','none','HorizontalAlignment','center','Interpreter','none');
colors = lines(count);
titles = {'Minimum certified QoS ratio','Users meeting certified full QoS', ...
    'Certified sum rate (full QoS required)','Sum rate at Z=1 (reference)','Accounted end-to-end runtime'};
if sampled
    if isfield(report,'validationSamples'), nValidation = report.validationSamples; else, nValidation = 1000; end
    titles{4} = sprintf('Mean sum rate (%d fresh fading periods)',nValidation);
end
ylabels = {'Ratio','Percent','Mbps','Mbps','Seconds'};
for k = 1:5
    subplot(2,3,k);
    plot(1:count,values.median(:,k),'-o','LineWidth',1.5,'MarkerSize',5,'Color',[.1,.4,.7]);
    hold on;
    errorbar(1:count,values.median(:,k),values.median(:,k)-values.low(:,k), ...
        values.high(:,k)-values.median(:,k),'k.','LineWidth',1);
    set(gca,'XTick',1:count,'XTickLabel',labels,'XTickLabelRotation',35,'TickLabelInterpreter','none');
    title(titles{k}); ylabel(ylabels{k}); xlabel('Method (categorical)'); grid on; xlim([.5,count+.5]);
    if k==3 || k==5
        for j=find(isfinite(values.median(:,k))).'
            text(j,values.median(j,k),sprintf(' %.2f',values.median(j,k)), ...
                'VerticalAlignment','bottom','FontSize',8);
        end
    end
    if k==1, ylim([0,1.05]); elseif k==2, ylim([0,105]); end
    limits = ylim;
    for j = find(~isfinite(values.median(:,k))).'
        label='N/A';
        if k==3 && strict, label='No full-QoS result'; end
        text(j,limits(1)+.03*diff(limits),label,'Rotation',90,'HorizontalAlignment','left');
    end
end
subplot(2,3,6); hold on;
for j = 1:count
    plot(1:size(values.userRatio,1),values.userRatio(:,j),'LineWidth',1.1,'Color',colors(j,:));
end
legend(labels,'Location','best','Interpreter','none'); xlabel('User'); ylabel('Certified service / demand');
title('Per-user QoS ratio (first requested seed)'); grid on;
if ~exist(directory,'dir'), mkdir(directory); end
print(fig,fullfile(directory,'method_comparison.png'),'-dpng','-r160');
if exist('savefig','file')~=0, savefig(fig,fullfile(directory,'method_comparison.fig')); end
end
