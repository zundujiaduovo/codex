function rows=run_leo_v13_refinement_report(report,directory)
% 导出每轮改进来源和候选切点误差；仅读取历史，不重跑搜索。
rows=struct([]);
names={'blockwiseAccepted','poolAccepted','bottleneckAccepted','retangentAccepted', ...
    'priceScheduleAccepted','recoveryAccepted','extraInnerCalls','candidateGapEvaluations', ...
    'candidateCutRefreshes','candidateCutSeconds','maxCandidateGapBefore','maxCandidateGapAfter','lambdaSum'};
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    for phase=1:2
        stage=report.solutions{j}.(sprintf('stage%d',phase));
        if ~isfield(stage,'rounds'), continue; end
        h=stage.history;
        for k=1:stage.rounds
            row=struct('method',leo_method_name(r.method),'seed',r.seed,'phase',phase,'round',k, ...
                'fairness',h.savedFairness(k),'totalBits',h.savedTotalBits(k));
            for n=1:numel(names)
                value=NaN; if isfield(h,names{n}), value=h.(names{n})(k); end
                row.(names{n})=value;
            end
            rows=leo_append_struct(rows,row);
        end
    end
end
leo_write_struct_csv(fullfile(directory,'refinement_rounds.csv'),rows);
fprintf('Refinement evidence saved: refinement_rounds.csv (acceptance sources, extra work, local candidate-cut errors).\n');
end
