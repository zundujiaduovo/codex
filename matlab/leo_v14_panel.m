function p=leo_v14_panel(titleText,xlabelText,ylabelText,kind,labels)
if nargin<4, kind='line'; end
if nargin<5, labels={}; end
p=struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText,'labels',{labels}, ...
 'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}}, ...
 'ylim',[],'reference',[],'referenceLabel','','note','');
end
