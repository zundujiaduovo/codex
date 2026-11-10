function fig = leo_plot_theory_bound(report,directory)
%LEO_PLOT_THEORY_BOUND 全用户 QoS 达标时：各方法最佳可行值与统一上界。
t = report.theory; methods = report.options.methods; N = numel(methods);
labels = methods;
known = {'sb_v8_blockwise','local_v8_blockwise','original_tabu_independent','price_local_blockwise','price_sb_joint','price_local_joint', ...
    'initial','original_greedy','original_exchange','original_tabu','price_sb','price_sb_blockwise', ...
    'price_sb_adaptive','price_sb_light','price_local','price_local_adaptive','price_miqp','proxy_milp', ...
    'sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
short = {'V8 SB','V8 Local matched','Tabu own start','V9 Local pool','SB pool+pair','V9 Local pool+pair', ...
    'Initial','Greedy','Exchange','Tabu common start','Price+SB','SB pool','SB adapt','SB light','Price+Local', ...
    'Local adapt','Price+MIQP','Proxy MILP','SB zero','SB minimax','SB current','SB portfolio'};
for j = 1:N
    index = find(strcmp(methods{j},known),1);
    if ~isempty(index), labels{j} = short{index}; end
end
period = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
scale = 1e6*period; best = NaN(N,1);
for j = 1:N
    ids = find(strcmp({report.records.method},methods{j})).';
    ids = ids(t.recordFeasible(ids));
    if ~isempty(ids), best(j) = max(t.recordServiceBits(ids))/scale; end
end
upper = t.upperBits/scale; lower = t.lowerBits/scale;
fig = figure('Visible','on','Color','w','Name','Theoretical bound at full QoS','Position',[50,50,1450,800]);
subplot(2,1,1); plot(1:N,best,'-o','LineWidth',1.5,'MarkerSize',5); hold on;
line([.5,N+.5],[upper,upper],'Color',[.8,0,0],'LineStyle','--','LineWidth',1.7);
set(gca,'XTick',1:N,'XTickLabel',labels,'XTickLabelRotation',35,'TickLabelInterpreter','none');
title('Certified sum rate: full-QoS feasible runs and common upper bound'); ylabel('Mbps'); grid on;
if isfinite(lower)
    line([.5,N+.5],[lower,lower],'Color',[0,.5,.2],'LineStyle',':','LineWidth',1.5);
    legend({'Method result','Global upper','Verified lower incl. certificate search'},'Location','best');
else
    legend({'Method result','Global upper'},'Location','best');
end
limits = ylim;
for j = find(~isfinite(best)).', text(j,limits(1)+.03*diff(limits),'N/A','Rotation',90); end
subplot(2,1,2);
if isfinite(lower)
    lo = max(0,lower-best); hi = max(0,upper-best);
    plot(1:N,lo,'-o',1:N,hi,'--s','LineWidth',1.5); legend({'At least','At most'},'Location','best');
else
    text(.1,.5,'No recorded full-QoS feasible schedule; lower gap unavailable','Units','normalized');
end
set(gca,'XTick',1:N,'XTickLabel',labels,'XTickLabelRotation',35,'TickLabelInterpreter','none');
xlabel('Method (categorical)'); xlim([.5,N+.5]);
title('Possible optimality gap interval at the same full-QoS floor'); ylabel('Mbps'); grid on;
caption='Bounds are for the fixed certified-service integer model.';
if isfield(t,'relativeGap') && isfinite(t.relativeGap)
    caption=sprintf('Verified integer interval [%.6f, %.6f] Mbit/period | remaining gap %.6f%% | target met %d', ...
        t.lowerBits/1e6,t.upperBits/1e6,100*t.relativeGap,t.gapTargetMet);
end
annotation(fig,'textbox',[0,.965,1,.035],'String',caption, ...
    'EdgeColor','none','HorizontalAlignment','center','Interpreter','none');
if ~exist(directory,'dir'), mkdir(directory); end
print(fig,fullfile(directory,'theoretical_bound.png'),'-dpng','-r160');
if exist('savefig','file')~=0, savefig(fig,fullfile(directory,'theoretical_bound.fig')); end
end
