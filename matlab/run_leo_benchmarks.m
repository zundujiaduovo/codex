function report = run_leo_benchmarks(caseOrParameters,overrides)
%RUN_LEO_BENCHMARKS 文档第 13.3 节统一对比主入口，固定 32 波束/最多 8 人。
% 输入：'small'(默认 8用户/3块)、'default'(32用户/20块)或自定义参数；可选实验覆盖。
% 输出：报告、全部 CSV/MAT/JSON 及图形后端可用时的 18 图 PNG/PDF/FIG；不自动缩小参数。
if nargin<1, caseOrParameters = 'small'; end
if nargin<2, overrides = struct(); end
options = leo_benchmark_options(overrides);
if isstruct(caseOrParameters)
    p = caseOrParameters; caseName = 'custom';
else
    caseName = caseOrParameters; p = leo_default_parameters();
    assert(any(strcmp(caseName,{'small','default'})));
    if strcmp(caseName,'small'), p.system.K = 8; p.time.nSlots = 15; end
end
p.method.enabled = false; p.exhaustive.enabled = false;
model = run_leo_sinr(p);
report = leo_benchmark_case(model,options);
report.caseName = caseName;
directory = options.outputDirectory;
if isempty(directory), directory = fullfile('results',['benchmark_',caseName]); end
report.outputDirectory = directory;
report.plotStatus = 'disabled';
leo_export_benchmark(report,directory);
if options.makePlots
    try
        report.plotFiles = run_leo_plot_results(fullfile(directory,'plot_data.mat'),directory);
        report.plotStatus = 'completed';
    catch err
        report.plotStatus = ['unavailable: ',err.message];
        warning('leo:plotUnavailable','图形导出未完成，数值结果仍导出: %s',err.message);
    end
end
save(fullfile(directory,'benchmark.mat'),'report','-v7');
end
