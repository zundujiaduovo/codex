% 固定代理/权重/旧组：在明确限制为最多12候选用户的块上枚举精确对照。
comparisonRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(comparisonRoot,'matlab'),'-begin'); rehash;
v12Directory=fullfile(comparisonRoot,'results','v12_uncapped_lexicographic');
proxyAudit=run_leo_v12_proxy_control(v12Directory,struct(),true);
out=fullfile(v12Directory,'proxy_control');
if exist(fullfile(out,'v12_proxy_control.fig'),'file')==2, openfig(fullfile(out,'v12_proxy_control.fig'),'new','visible'); end
