function metrics = leo_performance_metrics(data,options)
%LEO_PERFORMANCE_METRICS 共同预算下的到达质量时间、定时质量与过程平均界差。
% 仅使用已记录的全QoS解；未达到/未知保持NaN，不把预算当作达标时间。
if nargin<2, options=struct(); end
defaults=struct('gapTargetsPercent',[5,2,1,.5],'deadlinesSeconds',[1,5,10,30,60,120]);
fields=fieldnames(options); assert(all(ismember(fields,fieldnames(defaults))));
for j=1:numel(fields), defaults.(fields{j})=options.(fields{j}); end
options=defaults;
for f=fieldnames(options).'
    a=options.(f{1}); assert(isnumeric(a) && isvector(a) && ~isempty(a) && all(isfinite(a) & a>0));
    assert(numel(unique(a))==numel(a),'共同门槛/截止时间不能重复。');
end
assert(all(options.gapTargetsPercent<=100));
records=data.records; N=numel(records); traces=cell(1,N); eligible=false(1,N);
U=NaN;
if isfield(data,'theoryBounds') && ~isempty(data.theoryBounds), U=data.theoryBounds.upperBits; end
hasUpper=isscalar(U) && isfinite(U) && U>0;
for j=1:N
    r=records(j); t=[]; v=[];
    eligible(j)=strcmp(r.status,'completed') && full_qos(r);
    if eligible(j) && ~isempty(data.progress)
        rows=data.progress(strcmp({data.progress.method},r.method) & [data.progress.seed]==r.seed);
        if ~isempty(rows)
            keep=isfinite([rows.seconds]) & [rows.seconds]>=0 & [rows.fairness]>=1 & isfinite([rows.totalBits]);
            rows=rows(keep); t=[rows.seconds]; v=[rows.totalBits];
            [t,order]=sort(t); v=v(order);
            last=[diff(t)~=0,true]; if isempty(t), last=[]; end
            t=t(last); v=v(last);
        end
    end
    if hasUpper && ~isempty(v)
        assert(all(v<=U+1e-8*max(1,U)),'共同上界小于已记录全QoS解，不能生成性能差距。');
    end
    traces{j}=struct('time',t,'value',v);
end
metrics=struct('options',options,'upperBits',U,'budgetSeconds',data.budgetSeconds, ...
    'summary',struct([]),'targets',struct([]),'deadlines',struct([]));
for j=1:N
    r=records(j); tr=traces{j}; T=data.budgetSeconds;
    s=struct('method',r.method,'seed',r.seed,'status',r.status,'fullQosFeasible',eligible(j), ...
        'finalCertifiedBits',NaN,'finalUpperGapPercent',NaN,'firstFullQosSeconds',NaN, ...
        'windowStartSeconds',NaN,'windowEndSeconds',T,'timeAverageGapPercent',NaN, ...
        'worstDemandRatio',field(r,'worstDemandRatio'),'qosMarginPercent',NaN, ...
        'jainFairness',field(r,'jainFairness'),'sampleMeanTotalBits',field(r,'sampleMeanTotalBits'), ...
        'sampleJointSuccessRate',field(r,'sampleJointSuccessRate'), ...
        'sampleJointFailure95Upper',field(r,'sampleJointFailure95Upper'));
    s.searchEngine='saved_legacy'; if isfield(r,'searchEngine'), s.searchEngine=r.searchEngine; end
    if eligible(j)
        s.finalCertifiedBits=r.totalBits;
        if hasUpper, s.finalUpperGapPercent=max(0,100*(1-r.totalBits/U)); end
        s.qosMarginPercent=100*(s.worstDemandRatio-1);
        if ~isempty(tr.time), s.firstFullQosSeconds=tr.time(1); end
    end
    % 相同种子所有有日志且达标的方法共享同一评价起点和截止时间。
    peers=find([records.seed]==r.seed & eligible); starts=[];
    for k=peers
        if ~isempty(traces{k}.time), starts(end+1)=traces{k}.time(1); end %#ok<AGROW>
    end
    if ~isempty(starts), s.windowStartSeconds=max(starts); end
    if eligible(j) && hasUpper && ~isempty(tr.time) && isfinite(s.windowStartSeconds) && s.windowStartSeconds<T
        nodes=[s.windowStartSeconds,tr.time(tr.time>s.windowStartSeconds & tr.time<T),T];
        values=arrayfun(@(time) last_value(tr,time),nodes(1:end-1));
        if all(isfinite(values))
            gap=max(0,100*(1-values/U));
            s.timeAverageGapPercent=sum(diff(nodes).*gap)/(T-s.windowStartSeconds);
        end
    end
    metrics.summary=append(metrics.summary,s);
    for target=options.gapTargetsPercent(:).'
        a=struct('method',r.method,'seed',r.seed,'targetGapPercent',target, ...
            'firstRecordedHitSeconds',NaN,'hitWithinBudget',false,'status','not_reached');
        if ~eligible(j), a.status='no_full_qos_result';
        elseif ~hasUpper, a.status='upper_bound_unavailable';
        elseif isempty(tr.time), a.status='logs_unavailable';
        else
            hit=find(100*(1-tr.value/U)<=target+32*eps*max(1,target),1);
            if ~isempty(hit)
                a.firstRecordedHitSeconds=tr.time(hit); a.hitWithinBudget=tr.time(hit)<=T;
                if a.hitWithinBudget, a.status='reached'; else, a.status='reached_after_budget'; end
            end
        end
        metrics.targets=append(metrics.targets,a);
    end
    for deadline=options.deadlinesSeconds(:).'
        a=struct('method',r.method,'seed',r.seed,'deadlineSeconds',deadline, ...
            'certifiedBits',NaN,'upperGapPercent',NaN,'status','not_yet_recorded');
        if deadline>T, a.status='outside_budget';
        elseif ~eligible(j), a.status='no_full_qos_result';
        else
            value=last_value(tr,deadline);
            if isfinite(value)
                a.certifiedBits=value; a.status='available';
                if hasUpper, a.upperGapPercent=max(0,100*(1-value/U)); end
            end
        end
        metrics.deadlines=append(metrics.deadlines,a);
    end
end
metrics.scope=['Observed full-QoS incumbents only. First hit is a logged timestamp, not interpolation. ', ...
    'Average gap uses a common window per seed; an already returned solution remains available after stopping. ', ...
    'Unavailable initial intervals and unmet targets are not fabricated. Lower gap/time is better; QoS margin and Jain are auxiliary.'];
end
function yes=full_qos(r)
if isfield(r,'fullQosFeasible'), yes=logical(r.fullQosFeasible); else, yes=r.fairness>=1; end
end
function value=last_value(trace,time)
at=find(trace.time<=time,1,'last'); value=NaN;
if ~isempty(at), value=trace.value(at); end
end
function value=field(row,name)
value=NaN; if isfield(row,name), value=row.(name); end
end
function rows=append(rows,row)
if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
