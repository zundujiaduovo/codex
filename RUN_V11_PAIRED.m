% V11基于V10：20个搜索种子，同模型的Tabu、SB与配对Local，每方法120秒。
% 串行搜索预算约2小时，另有一次共同上界与独立验证；已有配对可恢复。
clear functions
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin');
rehash;
pairedDirectory=fullfile(comparisonRoot,'results','v11_based_on_v10_paired');
experiment=run_leo_v11_paired(pairedDirectory,struct(),true);
innerAudit=run_leo_v11_inner_control(pairedDirectory,struct(),true);
if ispc, winopen(pairedDirectory); end
pairedFigures=run_leo_v11_show_results(pairedDirectory);
