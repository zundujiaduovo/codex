function leo_export_theory_bound(report,directory)
%LEO_EXPORT_THEORY_BOUND 保存共同全用户 QoS 门槛下的上界与每次运行的差距区间。
t = report.theory; N = numel(report.records); period = report.parameters.time.nSlots*report.parameters.time.slotDurationS;
template = struct('method','','seed',NaN,'status','','fullQosFeasible',false, ...
    'guaranteedServiceBits',NaN,'conditionalUpperBits',NaN,'bestFeasibleBits',NaN, ...
    'gapAtLeastBits',NaN,'gapAtMostBits',NaN,'gapAtLeastPercent',NaN,'gapAtMostPercent',NaN);
rows = repmat(template,N,1);
for j = 1:N
    r = report.records(j); rows(j).method = r.method; rows(j).seed = r.seed; rows(j).status = r.status;
    rows(j).conditionalUpperBits = t.upperBits; rows(j).bestFeasibleBits = t.lowerBits;
    rows(j).fullQosFeasible = t.recordFeasible(j); rows(j).guaranteedServiceBits = t.recordServiceBits(j);
    if t.recordFeasible(j) && isfinite(t.lowerBits)
        value = t.recordServiceBits(j);
        rows(j).gapAtLeastBits = max(0,t.lowerBits-value);
        rows(j).gapAtMostBits = max(0,t.upperBits-value);
        rows(j).gapAtLeastPercent = 100*max(0,1-value/t.lowerBits);
        rows(j).gapAtMostPercent = 100*max(0,1-value/t.upperBits);
    end
end
if ~exist(directory,'dir'), mkdir(directory); end
leo_write_struct_csv(fullfile(directory,'theoretical_bound_by_run.csv'),rows);
summary = struct('fairnessFloor',t.fairnessFloor,'upperBits',t.upperBits, ...
    'upperMbps',t.upperBits/1e6/period,'lowerBits',t.lowerBits, ...
    'lowerMbps',t.lowerBits/1e6/period,'bestMethod',t.bestMethod,'bestSeed',t.bestSeed, ...
    'pricingComplete',t.pricingComplete,'pricingIterations',t.pricingIterations, ...
    'elapsedSeconds',t.elapsedSeconds,'kind',t.kind,'pricingStatus',t.pricingStatus,'scope',t.scope);
leo_write_struct_csv(fullfile(directory,'theoretical_bound_summary.csv'),summary);
theory = t; save(fullfile(directory,'theoretical_bound.mat'),'theory','-v7');
end
