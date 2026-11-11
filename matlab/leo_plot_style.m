function [color,style] = leo_plot_style(name,index)
%LEO_PLOT_STYLE 对照方法固定配色及线型，证书参考使用中性色。
if nargin<2, index=1; end
name=leo_method_id(name);
names={'initial','original_exchange','original_tabu','original_tabu_independent', ...
 'price_sb_blockwise','price_local_blockwise','price_sb_joint','price_local_joint'};
palette=[.45,.45,.45;.12,.4,.75;0,.5,.3;.1,.65,.65; ...
 .85,.15,.2;.9,.55,.05;.55,.2,.7;.6,.4,.2;.1,.55,.8;.85,.3,.6;.5,.6,.1;.2,.2,.2];
match=find(strcmp(name,names),1); if isempty(match), match=mod(index-1,size(palette,1))+1; end
color=palette(match,:); style='-';
if ~isempty(strfind(name,'local')), style='--'; end
if ~isempty(strfind(name,'independent')), style=':'; end
if ~isempty(strfind(name,'Verified lower')), color=[.4,.4,.4]; style=':'; end
if any(strcmp(name,{'sb_v8_blockwise','sb_v12_lexicographic'})), color=[.85,.15,.2]; style='-'; end
if any(strcmp(name,{'local_v8_blockwise','local_v12_lexicographic'})), color=[.2,.45,.85]; style='--'; end
if strcmp(name,'original_greedy'), color=[.1,.65,.65]; style='-'; end
if strcmp(name,'proxy_tabu'), color=[.55,.2,.7]; style='-.'; end
end
