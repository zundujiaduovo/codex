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
if isfield(t,'iterationTrace'), leo_write_struct_csv(fullfile(directory,'theoretical_bound_iterations.csv'),t.iterationTrace); end
if isfield(t,'blockTrace'), leo_write_struct_csv(fullfile(directory,'theoretical_bound_blocks.csv'),t.blockTrace); end
if isfield(t,'branchTrace'), leo_write_struct_csv(fullfile(directory,'theoretical_bound_nodes.csv'),t.branchTrace); end
if isfield(t,'incumbentX') && ~isempty(t.incumbentX)
    service=leo_evaluate_service(report.problemData,t.incumbentX); schedule=struct([]); users=struct([]);
    for i=1:report.problemData.shape(1)
        user=struct('user',i,'targetBits',report.problemData.qosTargetBits(i),'serviceBits',service.userBits(i));
        if isempty(users), users=user; else, users(end+1,1)=user; end
        for m=1:report.problemData.shape(2)
            row=struct('user',i,'resource',m,'selected',t.incumbentX(i,m),'beam',report.problemData.beamIndex(i,m));
            if isempty(schedule), schedule=row; else, schedule(end+1,1)=row; end
        end
    end
    leo_write_struct_csv(fullfile(directory,'certificate_incumbent_schedule.csv'),schedule);
    leo_write_struct_csv(fullfile(directory,'certificate_incumbent_users.csv'),users);
end
summary = struct('fairnessFloor',t.fairnessFloor,'upperBits',t.upperBits, ...
    'upperMbps',t.upperBits/1e6/period,'lowerBits',t.lowerBits, ...
    'lowerMbps',t.lowerBits/1e6/period,'bestMethod',t.bestMethod,'bestSeed',t.bestSeed, ...
    'pricingComplete',t.pricingComplete,'pricingIterations',t.pricingIterations, ...
    'elapsedSeconds',t.elapsedSeconds,'kind',t.kind,'pricingStatus',t.pricingStatus,'scope',t.scope);
for field={'nodesProcessed','openNodeCount','rootRelaxationUpperBits','rootLPConverged', ...
    'targetRelativeGap','relativeGap','absoluteGapBits','gapTargetMet','infeasibilityCertified', ...
    'cappedServiceRelaxation','minimumCountCuts'}
    if isfield(t,field{1}), summary.(field{1})=t.(field{1}); end
end
leo_write_struct_csv(fullfile(directory,'theoretical_bound_summary.csv'),summary);
theory = t; save(fullfile(directory,'theoretical_bound.mat'),'theory','-v7');
end
