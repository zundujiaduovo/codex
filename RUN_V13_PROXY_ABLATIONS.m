% 五配置配对对照：基线、仅加迭代、仅刷新、仅候选、三项合并。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V13_INSTALLATION(comparisonRoot);
[ablationRows,ablationFiles]=run_leo_v13_proxy_ablations(comparisonRoot,true);
