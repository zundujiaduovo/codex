function rows = leo_export_search_audit(report,directory)
%LEO_EXPORT_SEARCH_AUDIT 区分候选来源、原目标验收、恢复、联合协调及模块计时。
rows=struct([]); trace=struct([]);
names={'resourcesSolved','sbSteps','uniqueCandidates','solverBetterCalls', ...
    'blockwiseEvaluations','blockwiseAccepted','nonProxyAccepted','solverPoolAccepted', ...
    'polishPoolAccepted','warmPoolAccepted','jointEvaluations','jointAccepted', ...
    'acceptedMoves','recoveryEvaluations','innerSeconds','originalSelectionSeconds', ...
    'recoverySeconds','proxyRefreshSeconds','quboSetupSeconds','solverDynamicsSeconds', ...
    'candidatePostprocessSeconds','rawCandidates','legalRawCandidates'};
for j=1:numel(report.records)
    record=report.records(j); r=struct('method',record.method,'seed',record.seed, ...
        'usesQuadraticProxy',record.usesQuadraticProxy,'initializationPolicy',record.initializationPolicy);
    for f=names, r.(f{1})=NaN; end % V8/旧日志未记录的细分指标保持未知。
    if strcmp(record.status,'completed')
        for phase=1:2
            stage=report.solutions{j}.(sprintf('stage%d',phase)); h=stage.history;
            for f=names
                if isfield(h,f{1})
                    if isnan(r.(f{1})), r.(f{1})=0; end
                    r.(f{1})=r.(f{1})+sum(h.(f{1}));
                end
            end
            if isfield(stage,'checkpoints')
                c=stage.checkpoints;
                for k=2:numel(c.elapsedSeconds)
                    e=struct('method',record.method,'seed',record.seed,'phase',phase, ...
                        'seconds',record.commonSeconds+record.proxyPreparationSeconds+c.elapsedSeconds(k), ...
                        'kind',c.kind{k},'resource',c.resource(k), ...
                        'totalBits',c.savedTotalBits(k),'deltaBits',c.savedTotalBits(k)-c.savedTotalBits(k-1));
                    if isempty(trace), trace=e; else, trace(end+1,1)=e; end %#ok<AGROW>
                end
            end
        end
    end
    if isempty(rows), rows=r; else, rows(end+1,1)=r; end %#ok<AGROW>
end
leo_write_struct_csv(fullfile(directory,'search_module_audit.csv'),rows);
leo_write_struct_csv(fullfile(directory,'accepted_move_sources.csv'),trace);
end
