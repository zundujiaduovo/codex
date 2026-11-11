% 只显示已保存的V11汇总图；缺少图文件时从已有JSON重画，不重新运行实验。
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin');
rehash;
pairedDirectory=fullfile(comparisonRoot,'results','v11_based_on_v10_paired');
pairedFigures=run_leo_v11_show_results(pairedDirectory);
