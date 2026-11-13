function joined=leo_v17_merge_stage(previous,stage,cycle)
% Concatenate actual phase visits; elapsed time remains the method's real clock.
segment=struct('cycle',cycle,'status',stage.status,'initialFairness',stage.initialService.fairness, ...
    'finalFairness',stage.service.fairness,'finalTotalBits',stage.service.totalBits, ...
    'seconds',stage.elapsedAtEndSeconds,'floor',stage.fairnessFloor);
stage.history.cycle=repmat(cycle,1,numel(stage.history.elapsedSeconds));
stage.history.fairnessFloor=repmat(stage.fairnessFloor,1,numel(stage.history.elapsedSeconds));
if isfield(stage,'escapeEvents')
    for j=1:numel(stage.escapeEvents), stage.escapeEvents(j).cycle=cycle; end
end
if isempty(previous), joined=stage; joined.segments=segment; return; end
joined=stage; joined.segments=[previous.segments,segment];
joined.initialService=previous.initialService;
if isfield(previous,'initialElapsedSeconds'), joined.initialElapsedSeconds=previous.initialElapsedSeconds; end
if isfield(stage,'rounds'), offset=previous.rounds; joined.rounds=offset+stage.rounds;
else, offset=previous.iterations; joined.iterations=offset+stage.iterations; end
if isfield(stage,'evaluations'), joined.evaluations=previous.evaluations+stage.evaluations; end
h=stage.history;
if isfield(h,'iteration'), h.iteration=h.iteration+offset; end
if isfield(h,'evaluations'), h.evaluations=h.evaluations+previous.evaluations; end
for field=fieldnames(h).'
    name=field{1}; dimension=2; if strcmp(name,'priceX'), dimension=3; end
    joined.history.(name)=cat(dimension,previous.history.(name),h.(name));
end
if isfield(stage,'checkpoints')
    joined.checkpoints=stage.checkpoints;
    for field=fieldnames(stage.checkpoints).'
        name=field{1}; value=stage.checkpoints.(name);
        if strcmp(name,'iteration'), value=value+offset; end
        joined.checkpoints.(name)=[previous.checkpoints.(name),value];
    end
end
if isfield(stage,'sourceEvidence')
    joined.sourceEvidence=previous.sourceEvidence;
    for j=1:numel(stage.sourceEvidence)
        row=stage.sourceEvidence(j); row.round=row.round+offset;
        joined.sourceEvidence=leo_append_struct(joined.sourceEvidence,row);
    end
    if isfield(stage,'evidenceLimit')
        excess=max(0,numel(joined.sourceEvidence)-stage.evidenceLimit);
        joined.sourceEvidence(1:excess)=[];
        joined.evidenceDropped=previous.evidenceDropped+stage.evidenceDropped+excess;
    end
end
if isfield(stage,'escapeEvents')
    joined.escapeEvents=previous.escapeEvents;
    for j=1:numel(stage.escapeEvents), joined.escapeEvents=leo_append_struct(joined.escapeEvents,stage.escapeEvents(j)); end
end
if isfield(stage,'proxyEpochFairnessErrorBounds')
    joined.proxyEpochFairnessErrorBounds=[previous.proxyEpochFairnessErrorBounds,stage.proxyEpochFairnessErrorBounds];
    joined.proxyEpochTouchErrorsBits=[previous.proxyEpochTouchErrorsBits,stage.proxyEpochTouchErrorsBits];
end
if isfield(previous,'sbTrace') && ~isempty(previous.sbTrace), joined.sbTrace=previous.sbTrace; end
end
