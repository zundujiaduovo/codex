% 经验规模实验：K=8/16/32、M=20、3搜索种子、4方法；固定每算法迭代上限。
% 每方法最多60秒，已完成case可恢复；不把时间截断结果拟合为复杂度阶。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
scalingDirectory=fullfile(comparisonRoot,'results','v12_scaling');
scalingStudy=run_leo_v12_scaling(scalingDirectory,struct(),true);
if ispc, winopen(scalingDirectory); end
if exist(fullfile(scalingDirectory,'v12_empirical_scaling.fig'),'file')==2
    openfig(fullfile(scalingDirectory,'v12_empirical_scaling.fig'),'new','visible');
end
