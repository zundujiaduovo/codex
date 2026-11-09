function leo_export_benchmark(report,directory)
%LEO_EXPORT_BENCHMARK 导出实验 CSV/MAT 及全部可重画数值，包含迭代/价格/SB 能量日志。
% 输入：对比报告、目录；输出：目录内文件，无函数句柄序列化依赖。
if ~exist(directory,'dir'), mkdir(directory); end
leo_export_scenario(report,directory);
leo_write_struct_csv(fullfile(directory,'runs.csv'),report.records);
leo_write_struct_csv(fullfile(directory,'summary.csv'),report.summary);
users = struct([]); schedule = struct([]);
for r = 1:numel(report.records)
    if ~strcmp(report.records(r).status,'completed'), continue; end
    result = report.solutions{r}; row = report.records(r);
    for i = 1:report.problemData.shape(1)
        u = struct('method',row.method,'seed',row.seed,'user',i, ...
            'targetBits',report.problemData.qosTargetBits(i),'serviceBits',result.service.userBits(i), ...
            'demandRatio',result.service.demandRatio(i));
        if isempty(users), users = u; else, users(end+1,1) = orderfields(u,users); end
        for m = 1:report.problemData.shape(2)
            g = struct('method',row.method,'seed',row.seed,'user',i,'resource',m, ...
                'selected',logical(result.x(i,m)),'beam',report.problemData.beamIndex(i,m));
            if isempty(schedule), schedule = g; else, schedule(end+1,1) = orderfields(g,schedule); end
        end
    end
end
leo_write_struct_csv(fullfile(directory,'user_service.csv'),users);
leo_write_struct_csv(fullfile(directory,'schedules.csv'),schedule);
save(fullfile(directory,'benchmark.mat'),'report','-v7');
leo_export_plot_data(report,directory); % 即使 makePlots=false，也保留全部可重画数值。
end
