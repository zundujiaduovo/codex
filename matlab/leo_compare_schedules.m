function rows = leo_compare_schedules(problem,schedules,names)
%LEO_COMPARE_SCHEDULES 所有对照使用同一个问题和设计服务口径，不重新分配风险。
% 接口标注：
% 输入：problem：同一模型；schedules：日程 cell；names：对应标签 cell。
% 输出：rows：各日程原始公平、总服务 bit 和每用户服务结构体表。
assert(iscell(schedules) && iscell(names) && numel(schedules)==numel(names));
rows = struct('name',{},'fairness',{},'totalBits',{},'normalizedThroughput',{},'userBits',{});
for k = 1:numel(schedules)
    service = problem.evaluate(schedules{k});
    rows(k).name = names{k};
    rows(k).fairness = service.fairness;
    rows(k).totalBits = service.totalBits;
    rows(k).normalizedThroughput = service.normalizedThroughput;
    rows(k).userBits = service.userBits;
end
end
