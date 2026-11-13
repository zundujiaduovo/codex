function rows=run_leo_v17_search_audit(report,directory)
% Explicit phase handoffs and original-model rescue attribution.
rows=struct([]); rescues=struct([]);
for j=1:numel(report.records)
    record=report.records(j); if ~strcmp(record.status,'completed'), continue; end
    result=report.solutions{j};
    for phase=1:2
        stage=result.(sprintf('stage%d',phase));
        for k=1:numel(stage.segments)
            row=stage.segments(k); row.method=leo_method_name(record.method); row.seed=record.seed; row.phase=phase;
            rows=leo_append_struct(rows,row);
        end
        for k=1:numel(stage.escapeEvents)
            row=stage.escapeEvents(k); row.method=leo_method_name(record.method); row.seed=record.seed; row.phase=phase;
            rescues=leo_append_struct(rescues,row);
        end
    end
end
leo_write_struct_csv(fullfile(directory,'v17_phase_handoffs.csv'),rows);
leo_write_struct_csv(fullfile(directory,'v17_original_fairness_rescues.csv'),rescues);
end
