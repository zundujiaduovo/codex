function [rows,summary] = leo_export_proxy_audit(report,directory,maxNeighbors)
%LEO_EXPORT_PROXY_AUDIT 固定末次代理，比较同一日程原式与二次下界；不参与求解。
% 相切点单独标记，摘要只统计非参考点；邻域是确定性有限探针，不是全域抽样。
if nargin<3, maxNeighbors=24; end
assert(isscalar(maxNeighbors) && maxNeighbors>=0 && maxNeighbors==fix(maxNeighbors));
rows=struct([]); summary=struct([]); data=report.problemData;
problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
for j=1:numel(report.records)
    record=report.records(j);
    if ~strcmp(record.status,'completed'), continue; end
    result=report.solutions{j};
    if ~isfield(result.stage2,'proxy') || isempty(result.stage2.proxy), continue; end
    proxy=result.stage2.proxy; seen={}; first=numel(rows)+1;
    if ~isempty(proxy.referenceSchedule)
        original=problem.evaluate(proxy.referenceSchedule);
        probe(proxy.referenceSchedule,'reference',original);
    end
    probe(result.x,'final',result.service);
    h=result.stage2.history;
    if isfield(h,'priceX') && size(h.priceX,3)>0
        x=h.priceX(:,:,end); probe(x,'last_price',problem.evaluate(x));
    end
    pool=leo_original_neighbors(problem,result.x,result.service,maxNeighbors,1,[]);
    for k=1:numel(pool), probe(pool(k).x,sprintf('neighbor_%d',k),pool(k).service); end
    selected=rows(first:end); off=selected(~[selected.isReferencePoint]);
    feasible=off([off.fullQosFeasible]);
    s=struct('method',record.method,'seed',record.seed,'referenceMode',proxy.referenceMode, ...
        'probes',numel(selected),'offReferenceProbes',numel(off), ...
        'medianObservedClippedUnderestimatePercent',NaN,'maxObservedClippedUnderestimatePercent',NaN, ...
        'medianObservedSignedUnderestimatePercent',NaN,'offReferenceFullQosProbes',numel(feasible), ...
        'medianObservedFullQosClippedUnderestimatePercent',NaN, ...
        'maxObservedFullQosClippedUnderestimatePercent',NaN, ...
        'uniformTotalLowerErrorAllowanceBits',sum(proxy.error.lowerUserBits));
    if ~isempty(off)
        a=[off.clippedUnderestimatePercent]; a=a(isfinite(a));
        if ~isempty(a), s.medianObservedClippedUnderestimatePercent=median(a); s.maxObservedClippedUnderestimatePercent=max(a); end
        a=[off.signedUnderestimatePercent]; a=a(isfinite(a));
        if ~isempty(a), s.medianObservedSignedUnderestimatePercent=median(a); end
    end
    if ~isempty(feasible)
        a=[feasible.clippedUnderestimatePercent]; a=a(isfinite(a));
        if ~isempty(a)
            s.medianObservedFullQosClippedUnderestimatePercent=median(a);
            s.maxObservedFullQosClippedUnderestimatePercent=max(a);
        end
    end
    summary=append(summary,s);
end
leo_write_struct_csv(fullfile(directory,'proxy_error_probes.csv'),rows);
leo_write_struct_csv(fullfile(directory,'proxy_error_summary.csv'),summary);
    function probe(x,kind,original)
        for at=1:numel(seen), if isequal(seen{at},x), return; end; end
        seen{end+1}=x;
        lower=leo_evaluate_quadratic_service(data,proxy.lower,x);
        clipped=max(0,lower.userBits); gap=original.userBits-clipped;
        assert(all(gap>=-1e-8*max(1,abs(original.userBits))),'代理下界违反原式服务界。');
        r=struct('method',record.method,'seed',record.seed,'probeKind',kind, ...
            'referenceMode',proxy.referenceMode,'isReferencePoint',isequal(x,proxy.referenceSchedule), ...
            'fullQosFeasible',all(original.userBits>=data.qosTargetBits), ...
            'originalTotalBits',original.totalBits,'quadraticSignedTotalBits',sum(lower.userBits), ...
            'clippedLowerTotalBits',sum(clipped),'clippedUnderestimatePercent',NaN, ...
            'signedUnderestimatePercent',NaN,'maxUserClippedUnderestimateBits',max([0;gap]));
        if original.totalBits>0
            r.clippedUnderestimatePercent=100*max(0,1-sum(clipped)/original.totalBits);
            r.signedUnderestimatePercent=100*max(0,1-sum(lower.userBits)/original.totalBits);
        end
        rows=append(rows,r);
    end
end
function rows=append(rows,row)
if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
