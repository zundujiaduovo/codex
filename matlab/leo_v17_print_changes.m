function leo_v17_print_changes(o)
% Printed before the expensive worker/model setup; readable in MATLAB's window.
p=o.method.searchPolicy;
fprintf('\n========== V17：基于 V16 的搜索逻辑修正 ==========\n');
fprintf('1. 主实验保存解始终公平优先；吞吐阶段发现更高 s，保留该解并返回公平阶段。\n');
fprintf('2. 四种搜索方法公平停滞后进行最多 %d 次无改善的原式扰动/跨块搜索，每次 %d 轮；有改善则重置计数。\n',p.fairnessEscapes,p.escapeRounds);
fprintf('   探索轨迹允许暂时变差，保存的最好公平值不回退；共享恢复成本单独记录。\n');
fprintf('3. 所有可用用户使用当前日程的反事实干扰切点；检查候选池的原式/代理增益。\n');
fprintf('   增益预测失真时，在冻结候选池上选择误差更小的有效切线，最后仍按原问题验收。\n');
fprintf('4. bSB 保留 %d 条轨迹和实际 CPU worker 并行；固定 QUBO 内缓存重复修复。\n',o.method.sbTrajectories);
fprintf('5. 无时间或外层最大迭代上限；停止表示经验停滞，不代表全局最优。\n');
fprintf('6. 独立对照：相同公平门槛/初值；相同 QUBO 的串行与并行64轨迹、解质量上下界。\n');
fprintf('   原问题全局最优性仍由 RUN_V17_BOUNDS 的有效上下界判断。\n');
fprintf('Greedy 保留无改善添加即结束的基线规则。结果使用 V17 新目录，不复用 V16 搜索。\n================================================\n\n');
end
