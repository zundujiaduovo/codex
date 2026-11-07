function reports = run_leo_periodic_sweep(directory,overrides)
%RUN_LEO_PERIODIC_SWEEP 固定物理样本，预设 1/2/4 Mbit 负载、同预算方法对比。
% 可覆盖 leo_benchmark_options；不依据结果筛选种子/负载或改变物理资源。
if nargin<1, directory = fullfile('results','periodic_qos'); end
if nargin<2, overrides = struct(); end
options = leo_benchmark_options(overrides);
if ~isfield(overrides,'methods'), options.methods = {'initial','original_tabu','price_sb','price_local'}; end
options.exhaustive = false; options.makePlots = false;
reports = cell(1,3); loads = [1,2,4];
for j = 1:numel(loads)
    p = leo_default_parameters(); p.system.qosTargetBits = loads(j)*1e6;
    options.outputDirectory = fullfile(directory,sprintf('load_%d_Mbit',loads(j)));
    report = run_leo_benchmarks(p,options);
    validation = struct([]);
    for k = 1:numel(report.records)
        row = report.records(k);
        if ~strcmp(row.status,'completed') || row.seed~=options.seeds(1), continue; end
        mc = leo_sample_period_service(report.problemData,report.solutions{k}.x, ...
            10^(p.channel.ricianKDb/10),2000,20261108);
        v.method = row.method; v.loadMbit = loads(j); v.seed = row.seed;
        v.certifiedFairness = row.fairness; v.certifiedTotalMbit = row.totalBits/1e6;
        v.certifiedUserQosRate = row.qosSatisfactionRate;
        v.nominalTotalMbit = row.nominalTotalBits/1e6;
        v.mcMeanTotalMbit = mc.meanTotalBits/1e6; v.mcMeanUserQosRate = mc.meanUserQosRate;
        v.mcJointSuccessRate = mc.jointSuccessRate; v.mcJointFailure95Upper = mc.jointFailure95Upper;
        v.theoreticalJointSuccessLower = row.qosJointSuccessLower;
        validation(end+1,1) = v; %#ok<AGROW>
    end
    leo_write_struct_csv(fullfile(options.outputDirectory,'independent_validation.csv'),validation);
    reports{j} = report;
end
end
