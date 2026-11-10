function specs = leo_build_performance_specs(metrics,methods,seed)
%LEO_BUILD_PERFORMANCE_SPECS 预设质量门槛、固定时间质量、过程差距及QoS余量。
p=panel('categorical_line','Recorded time to a certified quality target','Gap target (%)','Seconds (missing = not reached)');
p.labels=arrayfun(@(v) sprintf('%.3g%%',v),metrics.options.gapTargetsPercent,'UniformOutput',false);
p(2)=panel('line','Quality at fixed elapsed-time deadlines','Accounted elapsed time (s)','Gap to upper bound (%)');
p(3)=panel('categorical_line','Time-average gap over the common window','Method','Average gap (%)');
p(3).labels=methods;
p(4)=panel('categorical_line','Uncapped worst-user QoS margin (auxiliary)','Method','100 (min G/q - 1) (%)');
p(4).labels=methods;
meanGap=NaN(1,numel(methods)); margin=meanGap;
for j=1:numel(methods)
    rows=metrics.targets(strcmp({metrics.targets.method},methods{j}) & [metrics.targets.seed]==seed);
    hit=NaN(1,numel(metrics.options.gapTargetsPercent));
    for k=1:numel(hit)
        at=find([rows.targetGapPercent]==metrics.options.gapTargetsPercent(k),1);
        if ~isempty(at) && rows(at).hitWithinBudget, hit(k)=rows(at).firstRecordedHitSeconds; end
    end
    p(1)=series(p(1),methods{j},1:numel(hit),hit);
    rows=metrics.deadlines(strcmp({metrics.deadlines.method},methods{j}) & [metrics.deadlines.seed]==seed);
    if ~isempty(rows), p(2)=series(p(2),methods{j},[rows.deadlineSeconds],[rows.upperGapPercent]); end
    rows=metrics.summary(strcmp({metrics.summary.method},methods{j}) & [metrics.summary.seed]==seed);
    if ~isempty(rows), meanGap(j)=rows(1).timeAverageGapPercent; margin(j)=rows(1).qosMarginPercent; end
end
p(3)=series(p(3),'Average upper-bound gap',1:numel(methods),meanGap);
p(4)=series(p(4),'Worst-user QoS margin',1:numel(methods),margin);
p(1).emptyMessage='No target reached within the budget';
if ~isfinite(metrics.upperBits), p(1).emptyMessage='Common upper bound unavailable'; end
p(2).emptyMessage='No upper-bound gap available at these deadlines';
p(1).note='Targets are fixed in advance. Never use the budget as the hitting time for an unreached target.';
p(2).note='Use the last logged solution available by each deadline; after an early return its solution remains available.';
p(3).note=metrics.scope;
p(4).note='QoS margin is not an additional optimization objective and need not improve with sum service.';
specs=struct('name','performance_metrics','title',sprintf('Common quality/time metrics | seed %.0f',seed), ...
    'rows',2,'cols',2,'panels',p);
end
function p=panel(kind,titleText,xlabelText,ylabelText)
p=struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText, ...
 'labels',{{}},'series',struct([]),'z',[],'zShape',[0,0],'clim',[], ...
 'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','','emptyMessage','');
end
function p=series(p,name,x,y)
s=struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]);
if isempty(p.series), p.series=s; else, p.series(end+1,1)=s; end
end
