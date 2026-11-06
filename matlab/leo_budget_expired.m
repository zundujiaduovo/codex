function expired = leo_budget_expired(budget)
%LEO_BUDGET_EXPIRED 软时间预算；每个有限原子操作完成后检查。
% 接口标注：
% 输入：budget：含 tic 句柄 timer 和秒数 seconds；[] 表示不设限。
% 输出：expired：逻辑标量，已达软时间上限。
expired = ~isempty(budget) && toc(budget.timer)>=budget.seconds;
end
