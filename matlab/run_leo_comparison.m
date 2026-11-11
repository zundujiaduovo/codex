function [report,files] = run_leo_comparison(directory,overrides,render)
%RUN_LEO_COMPARISON V12默认：未封顶公平优先；旧目标用run_leo_full_qos_comparison。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
[report,files]=run_leo_v12_comparison(directory,overrides,render);
end
