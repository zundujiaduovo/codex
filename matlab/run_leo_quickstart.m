function [report,fig] = run_leo_quickstart(outputDirectory,overrides)
%RUN_LEO_QUICKSTART 一键运行五种方法的对比，并显示/保存对比图。
if nargin<1, outputDirectory = fullfile('results','comparison'); end
if nargin<2, overrides = struct(); end
[report,fig] = run_leo_comparison(outputDirectory,overrides);
end
