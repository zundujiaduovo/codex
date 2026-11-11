function report = leo_v12_load_report(source)
%LEO_V12_LOAD_REPORT 读取已保存V12报告；不重新搜索或计算证书。
if isstruct(source), report=source;
else
    if exist(source,'dir')==7, source=fullfile(source,'benchmark.mat'); end
    assert(exist(source,'file')==2,['V12 benchmark.mat not found: ',source]);
    saved=load(source,'report'); assert(isfield(saved,'report'),'Expected a saved V12 report.');
    report=saved.report;
end
assert(leo_is_lexicographic(report.problemData),'This analysis requires the V12 uncapped objective.');
assert(numel(report.records)==numel(report.solutions));
end
