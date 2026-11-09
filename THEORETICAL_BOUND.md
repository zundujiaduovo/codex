# V7 全员 QoS 下的整数最优区间

当前采用完整组定价、列生成、合法强化和原变量分支定界，推导与实现边界见 [CERTIFICATE_SEARCH.md](CERTIFICATE_SEARCH.md)。目标与V6相同：固定保证模型下，所有用户G_i>=q_i后最大化sum G_i。

原始可行日程给下界L；全部未关闭分支给上界U，未知整数最优值V*满足L<=V*<=U。某方法的合法成绩V距最优的绝对差在[L-V,U-V]，相对差在[1-V/L,1-V/U]。没有整数可行日程时，不能把分数主问题的值填成L。

默认目标差距0.01%，180秒、128节点；达到目标才显示gapTargetMet=1。未达到时显示实际差距及停止原因。完整定价因规模/时间无法运行时，保留安全UB1或同一完整输入的已有证书界，不能将部分列池的解当全域上界。上界针对固定证书模型，不是物理平均吞吐的上界，也不保证其数值可达。

输出：theoretical_bound_summary.csv保存上下界、节点数、目标/实际差距和状态；theoretical_bound_by_run.csv保存每种算法的最优差距区间；theoretical_bound_iterations.csv保存完整定价过程；theoretical_bound_nodes.csv记录分支、关闭与预算状态；certificate_incumbent_schedule.csv和certificate_incumbent_users.csv给出独立验收的最好整数日程。证书搜索的新日程与被测算法成绩分别保存。

读取已有V6结果只重算证书，无需重跑算法：

```matlab
addpath('D:\code\LEO_QoS_Comparison_v7\matlab','-begin');
rehash
source='D:\code\LEO_QoS_Comparison_v6\results\comparison\seed_71669974\benchmark.mat';
[theory,fig]=run_leo_theory_from_saved(source,struct('maxSeconds',300));
```

结果默认另存于原结果目录下certificate_v7。用户此前L=7的108.645323与L=8的118.663265是不同配置的旧计算，不作为本版固定上界。

小规模精确验证包含：独立二元枚举最优、分数与整数有严格间隙的例子、分数可行但整数不可行、截断服务/计数割/分支条件下的完整定价核对、时间预算中断和保存恢复。对应test_leo_branch_price、test_leo_pricing_oracle、test_leo_theory_bound。
