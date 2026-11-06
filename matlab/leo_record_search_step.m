function history = leo_record_search_step(history,service,iteration,seconds,evaluations)
%LEO_RECORD_SEARCH_STEP 记录原目标搜索的已保存可行值，不改变选择/验收规则。
% 输入：历史结构、原始 service、原生步号、求解开始后的秒数、累计评价数。
% 输出：追加一列的历史；第 0 步是该阶段开始时的可行值。
if isempty(history)
    history = struct('iteration',[],'elapsedSeconds',[],'savedFairness',[], ...
        'savedTotalBits',[],'evaluations',[]);
end
history.iteration(end+1) = iteration;
history.elapsedSeconds(end+1) = seconds;
history.savedFairness(end+1) = service.fairness;
history.savedTotalBits(end+1) = service.totalBits;
history.evaluations(end+1) = evaluations;
end
