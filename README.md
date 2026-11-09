# LEO QoS V7：更紧的最优区间与公平的搜索预算

[下载 V7 纯源码包](LEO_QoS_Comparison_v7.zip)。分支leo-qos-v7-certified-gap；包内只有源码、测试代码和必要说明，不包含验证数据、图片、MAT或旧版ZIP。

配置延续V6：32用户、8×8阵元、32波束、最多8人、固定种子71669974、每用户1 Mbit、95%联合可靠性、每流10 W、80 W预算、1秒周期。G的定义和业务目标不变。

## 修改内容

1. 上界从有限轮价格迭代改为列生成与分支定价，并加入对原整数调度等价的截断服务表达和合法计数割。无需外部优化工具箱。默认争取把整数可行下界与全域上界的差距收至0.01%，最多180秒/128节点；未达到目标就显示真实剩余差距。
2. 证书阶段找到的新整数日程另存，绝不算进SB/禁忌成绩。分数主问题值不当成真实整数下界。
3. 对比默认仍是14项基础MATLAB方法/消融，每方法12秒软预算。价格+SB等方法的轮数上限由12/24提高到1000，避免在约2–3秒就因轮数结束，而禁忌继续跑满预算。日志打印停止原因；不保证SB排名领先。
4. 保留折线对比、场景核对文件和固定默认种子。历史上界或场景的数值不直接套到当前模型。

完整推导、证书精度和禁忌实现说明见 [CERTIFICATE_SEARCH.md](CERTIFICATE_SEARCH.md)。

## 运行完整比较

解压到新目录，例如D:\code\LEO_QoS_Comparison_v7，在MATLAB命令窗口运行：

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v7')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
[report,fig]=run_leo_comparison();
```

完整对比、1000周期独立验证及证书搜索可能需要数分钟。结果生成在results/comparison/seed_71669974，重复运行增加后缀，不覆盖。

## 只重算已有V6结果的证书

不必重跑14种算法：

```matlab
clear functions
cd('D:\code\LEO_QoS_Comparison_v7')
addpath(fullfile(pwd,'matlab'),'-begin')
rehash
source='D:\code\LEO_QoS_Comparison_v6\results\comparison\seed_71669974\benchmark.mat';
[theory,fig]=run_leo_theory_from_saved(source, ...
    struct('maxSeconds',300,'relativeGap',1e-4));
```

默认另存到旧结果目录下certificate_v7。重点看lowerBits、upperBits、relativeGap和gapTargetMet。输出最优区间、各算法差距范围、分支过程及最好证书整数日程。更长预算仍不保证所有实例都达到目标。

## 结果含义

goalStatus=full_qos_met表示通过当前充分证书的全员QoS门槛；full_qos_not_found保留诊断，不当作业务目标完成。证书搜索发生在方法比较结束后，单独计时；bestMethod=certificate_search时，该下界属于额外搜索，不是某个被测算法的成绩。比较方法质量使用各自返回的日程。

数学目标见FULL_QOS_MODEL.md；上界与新证书见THEORETICAL_BOUND.md和CERTIFICATE_SEARCH.md；方法字段见METHODS_AND_METRICS.md；种子/码本复现见REPRODUCIBILITY.md。所有图沿用折线或调度热图。

数值验证在Octave完成；包含独立整数枚举与分数间隙反例，不把同一实现的输出当作唯一oracle。MATLAB桌面图形未实机运行。固定证书的最优区间不能解释为真实随机物理容量的最优区间。
