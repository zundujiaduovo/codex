function files = leo_render_plot_specs(specs,directory)
%LEO_RENDER_PLOT_SPECS 基础 MATLAB 绘制全部规格，导出 PNG/PDF/可编辑 FIG。
% 输入：leo_build_plot_specs 输出、目录；输出：全部已保存文件的路径 cell。
% 兼容 R2018b；不依赖 Statistics Toolbox、tiledlayout 或 exportgraphics。
if ~exist(directory,'dir'), mkdir(directory); end
files = {};
for j = 1:numel(specs)
    spec = specs(j);
    fig = figure('Visible','off','Color','w','Position',[30,30,640*spec.cols,390*spec.rows+80]);
    cleanup = onCleanup(@() close(fig));
    for k = 1:numel(spec.panels)
        ax = subplot(spec.rows,spec.cols,k,'Parent',fig);
        draw_panel(ax,spec.panels(k));
    end
    annotation(fig,'textbox',[0,.96,1,.035],'String',spec.title,'EdgeColor','none', ...
        'HorizontalAlignment','center','FontWeight','bold','Interpreter','none');
    set(fig,'PaperPositionMode','auto');
    path = fullfile(directory,spec.name);
    print(fig,[path,'.png'],'-dpng','-r160'); files{end+1} = [path,'.png']; %#ok<AGROW>
    set(fig,'PaperUnits','inches'); sizeInches = get(fig,'Position');
    sizeInches = sizeInches(3:4)/get(0,'ScreenPixelsPerInch');
    set(fig,'PaperSize',sizeInches,'PaperPosition',[0,0,sizeInches]);
    print(fig,[path,'.pdf'],'-dpdf'); files{end+1} = [path,'.pdf']; %#ok<AGROW>
    if exist('savefig','file')~=0
        savefig(fig,[path,'.fig']); files{end+1} = [path,'.fig']; %#ok<AGROW>
    end
    clear cleanup;
end
end

function draw_panel(ax,p)
hold(ax,'on'); colors = lines(max(12,numel(p.series))); handles = {}; names = {};
hasValues = false;
if strcmp(p.kind,'heatmap')
    if ~isempty(p.z)
        h = imagesc(ax,p.z); set(h,'AlphaData',double(isfinite(p.z)));
        set(ax,'YDir','reverse'); axis(ax,'tight'); colorbar(ax); hasValues = any(isfinite(p.z(:)));
        if ~isempty(p.clim), caxis(ax,p.clim); end
        if size(p.z,2)<=12, set(ax,'XTick',1:size(p.z,2)); end
        if size(p.z,1)<=12, set(ax,'YTick',1:size(p.z,1)); end
        if ~isempty(p.xlabels), set(ax,'XTick',1:numel(p.xlabels),'XTickLabel',p.xlabels); end
        if ~isempty(p.ylabels), set(ax,'YTick',1:numel(p.ylabels),'YTickLabel',p.ylabels); end
    end
elseif strcmp(p.kind,'bar')
    count = numel(p.series); width = .8/max(1,count);
    for j = 1:count
        s = p.series(j); x = s.x+(j-(count+1)/2)*width;
        color = colors(j,:);
        h = bar(ax,x,s.y,width,'FaceColor',color,'EdgeColor','none');
        handles{end+1} = h; names{end+1} = s.name; %#ok<AGROW>
        if ~isempty(s.low)
            errorbar(ax,x,s.y,s.y-s.low,s.high-s.y,'k.','LineWidth',.7,'HandleVisibility','off');
        end
        hasValues = hasValues || any(isfinite(s.y));
    end
    set(ax,'XTick',1:numel(p.labels),'XTickLabel',p.labels,'XTickLabelRotation',35);
    if numel(p.labels)>1, xlim(ax,[.4,numel(p.labels)+.6]); end
else
    for j = 1:numel(p.series)
        s = p.series(j); color = line_color(s.name,colors(j,:));
        if strcmp(p.kind,'scatter')
            h = scatter(ax,s.x,s.y,30,color,'filled');
        elseif strcmp(p.kind,'step')
            h = stairs(ax,s.x,s.y,'Color',color,'LineWidth',1.4);
        else
            h = plot(ax,s.x,s.y,'Color',color,'LineWidth',1.4);
            if numel(s.x)<3, set(h,'Marker','o'); end
        end
        handles{end+1} = h; names{end+1} = s.name; %#ok<AGROW>
        hasValues = hasValues || any(isfinite(s.y));
    end
    if ~isempty(p.xlabels), set(ax,'XTick',1:numel(p.xlabels),'XTickLabel',p.xlabels); end
    if ~isempty(strfind(p.xlabel,'Price round')) && ~isempty(p.series) %#ok<STREMP>
        steps = unique([p.series.x]);
        if numel(steps)<=12, set(ax,'XTick',steps); end
    end
end
if ~hasValues
    text(ax,.5,.5,'Not applicable / not reported','Units','normalized','HorizontalAlignment','center','Color',[.4,.4,.4]);
    if strcmp(p.kind,'bar'), ylim(ax,[0,1]); set(ax,'YTick',[]); end
elseif strcmp(p.kind,'bar') && ~isempty(p.series)
    missing = true(size(p.series(1).y));
    for j = 1:numel(p.series), missing = missing & ~isfinite(p.series(j).y); end
    bounds = ylim(ax); level = bounds(1)+.03*diff(bounds);
    for x = find(missing), text(ax,x,level,'N/A','HorizontalAlignment','center','FontSize',7,'Color',[.4,.4,.4]); end
end
if ~isempty(p.reference)
    limits = xlim(ax);
    plot(ax,limits,[p.reference,p.reference],'k--','HandleVisibility','off');
    if ~isempty(p.referenceLabel)
        text(ax,limits(1),p.reference,[' ',p.referenceLabel],'VerticalAlignment','bottom','FontSize',8);
    end
end
if ~isempty(p.ylim), ylim(ax,p.ylim); end
heading = {p.title};
if ~isempty(p.note), heading = [heading,wrap_note(p.note,72)]; end
title(ax,heading,'Interpreter','none','FontSize',10);
xlabel(ax,p.xlabel,'Interpreter','none'); ylabel(ax,p.ylabel,'Interpreter','none');
set(ax,'FontSize',9,'TickLabelInterpreter','none'); box(ax,'off');
if ~strcmp(p.kind,'heatmap'), grid(ax,'on'); end
if numel(handles)>1
    legend(ax,[handles{:}],names,'Interpreter','none','Location','best','FontSize',7);
end
end

function result = wrap_note(note,width)
words = strsplit(note); result = {}; line = '';
for j = 1:numel(words)
    if numel(line)+numel(words{j})>width && ~isempty(line)
        result{end+1} = line; line = ''; %#ok<AGROW>
    end
    line = strtrim([line,' ',words{j}]);
end
if ~isempty(line), result{end+1} = line; end
end

function color = line_color(name,fallback)
names = {'Initial','Greedy','Exchange','Tabu','Price+SB','Price+Local','Price+MIQP','Proxy MILP', ...
    'SB: zero','SB: minimax','SB: current','SB: portfolio'};
colors = lines(12); index = find(strcmp(names,name),1);
color = fallback; if ~isempty(index), color = colors(index,:); end
end
