% 直接打开本文件，点击 MATLAB 的“运行”（F5）即可得到五种方法对比图。
comparisonRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin');
rehash;
[report,fig] = run_leo_comparison(fullfile(comparisonRoot,'results','comparison'));
