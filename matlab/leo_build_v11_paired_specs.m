function specs = leo_build_v11_paired_specs(summary)
%LEO_BUILD_V11_PAIRED_SPECS 配对差值/CI、逐种子差值、目标成功率和认证服务。
s=summary.statistics; methods={summary.methods.method};
p=panel('categorical_line','SB minus baseline: mean and pointwise 95% paired CI','Baseline','Certified service difference (Mbit/period)');
p.labels={s.baseline};
p=series(p,'Paired mean difference',1:numel(s),[s.meanDeltaBits]/1e6, ...
    [s.meanDelta95LowBits]/1e6,[s.meanDelta95HighBits]/1e6);
p.reference=0; p.referenceLabel='Equal certified service';
p(2)=panel('line','Paired differences for every requested search seed','Pair index (see search_seeds.csv)','SB minus baseline (Mbit/period)');
for j=1:numel(s)
    values=NaN(1,numel(summary.protocol.seeds));
    for k=1:numel(values)
        rows=summary.pairs(strcmp({summary.pairs.baseline},s(j).baseline) & [summary.pairs.seed]==summary.protocol.seeds(k));
        if ~isempty(rows), values(k)=rows.deltaBits/1e6; end
    end
    p(2)=series(p(2),['SB minus ',s(j).baseline],1:numel(values),values,[],[]);
end
p(2).reference=0; p(2).referenceLabel='Equal certified service';
p(3)=panel('categorical_line','Fraction reaching the same quality targets within budget','Gap target (%)','Successful runs (%)');
targets=unique([summary.targets.targetGapPercent]); targets=sort(targets,'descend');
p(3).labels=arrayfun(@(a) sprintf('%.3g%%',a),targets,'UniformOutput',false);
for j=1:numel(methods)
    values=NaN(size(targets));
    for k=1:numel(targets)
        r=summary.targets(strcmp({summary.targets.method},methods{j}) & [summary.targets.targetGapPercent]==targets(k));
        if ~isempty(r), values(k)=100*r.successRate; end
    end
    p(3)=series(p(3),methods{j},1:numel(targets),values,[],[]);
end
p(3).ylim=[0,105];
p(4)=panel('categorical_line','Original-model certified service: mean and observed range','Method','Certified service (Mbit/period)');
p(4).labels=methods;
p(4)=series(p(4),'Mean; min/max across search seeds',1:numel(methods), ...
    [summary.methods.meanCertifiedBits]/1e6,[summary.methods.minCertifiedBits]/1e6,[summary.methods.maxCertifiedBits]/1e6);
p(4).reference=summary.theoryUpperBits/1e6; p(4).referenceLabel='Common original-model upper bound';
p(1).note='Positive favors SB. Percentile bootstrap resamples paired search-seed differences. Failed/missing pairs are omitted and counted in the CSV.';
p(2).note='All preregistered search seeds, including SB losses. This is one fixed physical scene.';
p(3).note='Unreached targets are counted as unsuccessful; hitting times remain missing, not equal to the budget.';
p(4).note='The original certified service G is the optimization target. Independent fading means are a separate metric. Final returned scores use the V10 soft budget convention.';
specs=struct('name','v11_based_on_v10_paired','title',sprintf('V11 based on V10 | %d paired search seeds | %.0f s/method', ...
    numel(summary.protocol.seeds),summary.protocol.budgetSeconds),'rows',2,'cols',2,'panels',p);
end
function p=panel(kind,titleText,xlabelText,ylabelText)
p=struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText, ...
    'labels',{{}},'series',struct([]),'z',[],'zShape',[0,0],'clim',[], ...
    'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=series(p,name,x,y,low,high)
s=struct('name',name,'x',x(:).','y',y(:).','low',low(:).','high',high(:).');
p.series=leo_append_struct(p.series,s);
end
