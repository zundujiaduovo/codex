function rows = leo_stopping_rows(report)
%LEO_STOPPING_ROWS 两阶段停止原因和原目标差距；旧日志未知值保持NaN。
rows=struct([]);
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    solution=report.solutions{j};
    for phase=1:2
        stage=solution.(sprintf('stage%d',phase)); floorValue=0;
        if phase==2, floorValue=solution.fairnessFloor; end
        row=struct('method',leo_method_name(r.method),'seed',r.seed,'phase',phase, ...
            'stopReason',stage.status,'fixedFairnessFloor',floorValue,'enabled',NaN, ...
            'relativeGapTarget',NaN,'validRelativeGap',NaN,'nearOptimalCertified',NaN, ...
            'phaseSeconds',NaN,'stagnantSeconds',NaN, ...
            'empiricalConvergence',false,'convergenceWindowRounds',NaN,'stableWindows',NaN, ...
            'requiredStableWindows',NaN,'lastWindowGain',NaN,'windowTolerance',NaN, ...
            'scope','Stage 1: original max-min fairness. Stage 2: original total service conditional on the stated floor. Stagnation does not certify near-optimality.');
        if isfield(stage,'stopping')
            s=stage.stopping; row.enabled=s.options.enabled;
            row.relativeGapTarget=s.options.relativeGap; row.validRelativeGap=s.relativeGap;
            row.nearOptimalCertified=s.nearOptimalCertified;
            row.phaseSeconds=s.phaseSeconds; row.stagnantSeconds=s.stagnantSeconds;
            if isfield(s,'convergence')
                c=s.convergence; row.empiricalConvergence=c.heuristicConverged;
                row.convergenceWindowRounds=c.options.windowRounds; row.stableWindows=c.stableWindows;
                row.requiredStableWindows=c.options.stableWindows; row.lastWindowGain=c.lastWindowGain;
                row.windowTolerance=c.lastWindowTolerance;
            end
        end
        rows=leo_append_struct(rows,row);
    end
end
end
