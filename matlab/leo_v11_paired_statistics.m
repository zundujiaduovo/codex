function rows = leo_v11_paired_statistics(pairs,options)
%LEO_V11_PAIRED_STATISTICS 按种子差值作配对bootstrap；失败/缺失不算零。
% 95%逐比较百分位CI；两个主比较的双侧精确sign检验使用Holm校正。
previous=rng; cleanup=onCleanup(@() rng(previous)); %#ok<NASGU>
rng(options.bootstrapSeed,'twister'); rows=struct([]);
baselines={'original_tabu','local_v8_blockwise'};
for j=1:numel(baselines)
    selected=pairs(strcmp({pairs.baseline},baselines{j}));
    assert(numel(unique([selected.seed]))==numel(selected) && all(ismember([selected.seed],options.seeds)), ...
        'Each baseline must have at most one observation per requested search seed.');
    delta=[selected.deltaBits]; valid=isfinite(delta); values=delta(valid);
    r=struct('method','sb_v8_blockwise','baseline',baselines{j}, ...
        'expectedPairs',numel(options.seeds),'availablePairs',numel(values), ...
        'missingPairs',numel(options.seeds)-numel(values),'tieToleranceBits',options.tieToleranceBits, ...
        'wins',0,'ties',0,'losses',0,'winRate',NaN,'meanDeltaBits',NaN, ...
        'medianDeltaBits',NaN,'meanRelativeGainPercent',NaN, ...
        'meanDelta95LowBits',NaN,'meanDelta95HighBits',NaN, ...
        'signTestTwoSidedP',NaN,'signTestHolmP',NaN, ...
        'budgetAvailablePairs',0,'meanBudgetDeltaBits',NaN, ...
        'meanBudgetDelta95LowBits',NaN,'meanBudgetDelta95HighBits',NaN);
    if ~isempty(values)
        r.wins=sum(values>options.tieToleranceBits); r.losses=sum(values<-options.tieToleranceBits);
        r.ties=numel(values)-r.wins-r.losses; r.winRate=r.wins/numel(values);
        r.meanDeltaBits=mean(values); r.medianDeltaBits=median(values);
        r.meanRelativeGainPercent=mean([selected(valid).relativeGainPercent]);
        ci=mean_interval(values,options.bootstrapSamples);
        r.meanDelta95LowBits=ci(1); r.meanDelta95HighBits=ci(2);
        r.signTestTwoSidedP=sign_test(r.wins,r.losses);
    end
    values=[selected.deltaBudgetBits]; values=values(isfinite(values));
    r.budgetAvailablePairs=numel(values);
    if ~isempty(values)
        r.meanBudgetDeltaBits=mean(values); ci=mean_interval(values,options.bootstrapSamples);
        r.meanBudgetDelta95LowBits=ci(1); r.meanBudgetDelta95HighBits=ci(2);
    end
    rows=leo_append_struct(rows,r);
end
p=[rows.signTestTwoSidedP]; ids=find(isfinite(p)); [~,order]=sort(p(ids)); ids=ids(order);
previousP=0;
for j=1:numel(ids)
    previousP=max(previousP,min(1,(numel(baselines)-j+1)*p(ids(j))));
    rows(ids(j)).signTestHolmP=previousP;
end
end
function ci=mean_interval(values,count)
if numel(values)<2, ci=[NaN,NaN]; return; end
values=values(:); sample=values(randi(numel(values),numel(values),count));
means=sort(mean(sample,1)); ci=zeros(1,2); probabilities=[.025,.975];
for j=1:2
    position=1+(count-1)*probabilities(j); left=floor(position); right=ceil(position);
    ci(j)=means(left)+(position-left)*(means(right)-means(left));
end
end
function p=sign_test(wins,losses)
n=wins+losses; if n==0, p=1; return; end
k=0:min(wins,losses);
p=min(1,2*sum(exp(gammaln(n+1)-gammaln(k+1)-gammaln(n-k+1)-n*log(2))));
end
