function data = leo_v11_trace_data(report)
%LEO_V11_TRACE_DATA 只提取V10真实质量时间检查点；不展开多种子的逐用户价格表。
data=struct('records',report.records,'progress',struct([]),'budgetSeconds',report.options.budgetSeconds,'theoryBounds',struct([]));
if isfield(report,'theory'), data.theoryBounds=struct('upperBits',report.theory.upperBits,'lowerBits',report.theory.lowerBits); end
for j=1:numel(report.records)
    row=report.records(j); if ~strcmp(row.status,'completed'), continue; end
    result=report.solutions{j}; offset=row.commonSeconds+row.proxyPreparationSeconds;
    initial=NaN;
    if isfield(result,'initializationSeconds'), initial=result.initializationSeconds;
    elseif isfield(result.stage1,'history')
        h=result.stage1.history;
        if isfield(h,'iteration') && ~isempty(h.iteration) && h.iteration(1)==0, initial=h.elapsedSeconds(1); end
    end
    if isfinite(initial), add(offset+initial,result.initial.service,'initial'); end
    for phase=1:2
        stage=result.(sprintf('stage%d',phase));
        if isfield(stage,'initialElapsedSeconds'), add(offset+stage.initialElapsedSeconds,stage.initialService,'phase_initial'); end
        if isfield(stage,'history')
            h=stage.history;
            for k=1:numel(h.elapsedSeconds)
                s=struct('fairness',h.savedFairness(k),'totalBits',h.savedTotalBits(k));
                add(offset+h.elapsedSeconds(k),s,'phase');
            end
        end
        if isfield(stage,'checkpoints') && ~isempty(stage.checkpoints)
            h=stage.checkpoints;
            for k=1:numel(h.elapsedSeconds)
                s=struct('fairness',h.savedFairness(k),'totalBits',h.savedTotalBits(k));
                add(offset+h.elapsedSeconds(k),s,'checkpoint');
            end
        end
        if isfield(stage,'elapsedAtEndSeconds'), add(offset+stage.elapsedAtEndSeconds,stage.service,'phase_end'); end
    end
    add(row.endToEndSeconds,result.service,'final');
end
if ~isempty(data.progress)
    [~,order]=sortrows([[data.progress.seconds].',(1:numel(data.progress)).'],[1,2]);
    data.progress=data.progress(order);
end
    function add(seconds,service,kind)
        point=struct('method',row.method,'seed',row.seed,'seconds',seconds, ...
            'fairness',service.fairness,'totalBits',service.totalBits,'kind',kind);
        data.progress=leo_append_struct(data.progress,point);
    end
end
