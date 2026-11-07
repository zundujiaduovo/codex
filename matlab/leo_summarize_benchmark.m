function summary = leo_summarize_benchmark(records,methods)
%LEO_SUMMARIZE_BENCHMARK 第 13.3 节：分别统计成功/缺失/失败、典型值及最好完整运行。
% 输入：逐次记录与方法列表；输出每方法一行；缺失结果不当作零或成功样本。
summary = struct([]);
for j = 1:numel(methods)
    rows = records(strcmp({records.method},methods{j}));
    good = rows(strcmp({rows.status},'completed'));
    s.method = methods{j}; s.runs = numel(rows); s.completed = numel(good);
    s.unavailable = sum(strcmp({rows.status},'unavailable')); s.failed = sum(strcmp({rows.status},'failed'));
    s.medianFairness = NaN; s.bestFairness = NaN; s.bestRunTotalBits = NaN;
    s.medianTotalBits = NaN; s.medianQosSatisfactionRate = NaN; s.hardFeasibleRate = NaN;
    s.medianEndToEndSeconds = NaN; s.maxBudgetOverrunSeconds = NaN;
    s.medianFairnessGap = NaN; s.medianExactFairnessGap = NaN;
    if ~isempty(good)
        s.medianFairness = median([good.fairness]); s.bestFairness = max([good.fairness]);
        best = good([good.fairness]==s.bestFairness); s.bestRunTotalBits = max([best.totalBits]);
        s.medianTotalBits = median([good.totalBits]); s.medianQosSatisfactionRate = median([good.qosSatisfactionRate]);
        s.hardFeasibleRate = mean([good.hardFeasible]);
        s.medianEndToEndSeconds = median([good.endToEndSeconds]);
        s.maxBudgetOverrunSeconds = max([good.budgetOverrunSeconds]);
        s.medianFairnessGap = median([good.fairnessGap]);
        exact = [good.exactFairnessGap]; exact = exact(isfinite(exact));
        if ~isempty(exact), s.medianExactFairnessGap = median(exact); end
    end
    summary = leo_append_struct(summary,s);
end
end
