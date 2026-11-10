function specs = leo_build_sb_convergence_specs(data)
%LEO_BUILD_SB_CONVERGENCE_SPECS 每种SB的真实日志曲线；不优化、不补造未记录轨迹。
known={'price_sb','price_sb_blockwise','price_sb_joint','price_sb_adaptive','price_sb_light', ...
 'sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
allMethods=data.methods(:).';
methods=allMethods(ismember(allMethods,known)); seed=data.representativeSeed;
specs=struct([]); if isempty(methods), return; end
strict=isfield(data,'requireFullQos') && data.requireFullQos;
stamp=sprintf('Recorded search checkpoints | seed %.0f | K=%d, M=%d, L=%d', ...
 seed,data.shape(1),data.shape(2),data.maxStreams);
% 按时间比较各SB，并保留同场景禁忌/局部搜索参照；不跨算法比较原生迭代号。
overlay=[methods,allMethods(ismember(allMethods,{'original_exchange','original_tabu', ...
 'original_tabu_independent','price_local_blockwise','price_local_joint','price_local_adaptive'}))];
p=panel('step','Full-QoS certified service versus time','Accounted elapsed time (s)','Mbit/period');
q=panel('step','Gap to common upper bound versus time','Accounted elapsed time (s)','100 (U - V) / U (%)');
for j=1:numel(overlay)
 rows=select(data.progress,overlay{j},seed);
 rows=time_order(rows);
 if isempty(rows), continue; end
 y=[rows.totalBits]/1e6; if strict, y([rows.fairness]<1)=NaN; end
 p=series(p,overlay{j},[rows.seconds],y);
 q=add_gap(q,overlay{j},[rows.seconds],y*1e6,data);
end
p=add_bounds(p,data,strict); p.note='Only logged checkpoints; curves end when that method stops. Missing full-QoS values stay missing.';
earlyP=p; earlyQ=q; earlyP.title='Early search: certified service'; earlyQ.title='Early search: upper-bound gap';
earlyP.xlim=[0,15]; earlyQ.xlim=[0,15];
specs=figure_spec(specs,'sb_convergence_comparison',stamp,2,2,[p,q,earlyP,earlyQ]);
for j=1:numel(methods)
 method=methods{j}; rows=time_order(select(data.progress,method,seed));
 p=panel('step','Saved certified service versus time','Accounted elapsed time (s)','Mbit/period');
 p(2)=panel('step','Gap to common upper bound','Accounted elapsed time (s)','100 (U - V) / U (%)');
 if ~isempty(rows)
  y=[rows.totalBits]/1e6; if strict, y([rows.fairness]<1)=NaN; end
  p(1)=series(p(1),method,[rows.seconds],y);
  p(2)=add_gap(p(2),method,[rows.seconds],y*1e6,data);
 end
 p(1)=add_bounds(p(1),data,strict);
 p(1).note='True logged incumbent values; no cumulative-max correction and no extension after stopping.';
 if strict, p(1).note=[p(1).note,' Before full QoS the throughput curve is missing; see fairness.']; end
 if strcmp(method,'sb_reference_portfolio')
  p(1).note=[p(1).note,' Portfolio outer checkpoints record completed members, not hidden intermediate results.'];
 end
 p(3)=panel('step','Saved service by phase-local price round','Price round (restarts by phase/member)','Mbit/period');
 events=select(data.events,method,seed);
 if ~isempty(events)
  members=unique({events.member},'stable');
  for phase=1:2
   for r=1:numel(members)
    e=events([events.phase]==phase & strcmp({events.member},members{r}));
    if isempty(e), continue; end
    [~,order]=sort([e.iteration]); e=e(order);
    if max([e.iteration])==0, continue; end % 未执行阶段，不伪造零轮收敛轨迹。
    values=[e.totalBits]/1e6;
    label=sprintf('%s phase %d',members{r},phase);
    if phase==2 && strict, values([e.fairness]<1)=NaN; end
    p(3)=series(p(3),label,[e.iteration],values);
   end
  end
 end
 if numel(p(3).series)==1, p(3).title=[p(3).title,' | ',p(3).series(1).name]; end
 p(3).note='Different members/phases have separate counters. Phase-1 service can decrease as fairness improves. No curve means no logged search in that phase.';
 p(4)=panel('line','One fixed Ising call: best-so-far energy','SB integration step','Discrete Ising energy before repair');
 energy=select(data.energy,method,seed);
 if ~isempty(energy)
  preferred=energy([energy.phase]==2); if isempty(preferred), preferred=energy; end
  first=preferred(1);
  e=preferred([preferred.phase]==first.phase & [preferred.resource]==first.resource & ...
    [preferred.priceIteration]==first.priceIteration & strcmp({preferred.member},first.member));
  [~,order]=sort([e.step]); e=e(order);
  p(4)=series(p(4),'Minimum trajectory best',[e.step],[e.minimum]);
  p(4)=series(p(4),'Median trajectory best',[e.step],[e.median]);
  p(4)=series(p(4),'Maximum trajectory best',[e.step],[e.maximum]);
  p(4).title=sprintf('Fixed Ising call: %s, phase %d, block %d, price round %d', ...
   first.member,first.phase,first.resource,first.priceIteration);
  p(4).note='One stored fixed call only, before repair/polish. Different calls/methods change J,h,penalties: do not join or compare their energy levels.';
 else
  p(4).note='No fixed Ising call was recorded (stage skipped, solver unavailable or old logs missing); no zero curve is invented.';
 end
 titleText=sprintf('%s | %s',method,stamp);
 specs=figure_spec(specs,['sb_convergence_',method],titleText,2,2,p);
end
end
function rows=select(rows,method,seed)
if isempty(rows), rows=struct([]); return; end
rows=rows(strcmp({rows.method},method) & [rows.seed]==seed);
end
function rows=time_order(rows)
if isempty(rows), return; end
rows=rows(isfinite([rows.seconds])); if isempty(rows), return; end
[~,order]=sortrows([[rows.seconds].',(1:numel(rows)).'],[1,2]); rows=rows(order);
end
function p=add_bounds(p,data,strict)
if ~strict || ~isfield(data,'theoryBounds') || isempty(data.theoryBounds), return; end
b=data.theoryBounds;
if isfinite(b.upperBits), p.reference=b.upperBits/1e6; p.referenceLabel='Global certificate upper'; end
if isfinite(b.lowerBits) && ~isempty(p.series)
 x=[p.series.x]; x=x(isfinite(x));
 if ~isempty(x)
  limits=[min(x),max(x)];
  p=series(p,'Verified lower (extra certificate search)',limits,repmat(b.lowerBits/1e6,1,2));
 end
end
end
function p=add_gap(p,name,x,value,data)
if isfield(data,'theoryBounds') && ~isempty(data.theoryBounds) && isfinite(data.theoryBounds.upperBits) && data.theoryBounds.upperBits>0
 gap=100*(1-value/data.theoryBounds.upperBits); finite=isfinite(gap);
 gap(finite)=max(0,gap(finite)); % max(0,NaN) 在部分运行时会吞掉缺失值。
 p=series(p,name,x,gap);
else
 p.note='No common theoretical upper bound is present in the saved data; no gap is invented.';
end
end
function p=panel(kind,titleText,xlabelText,ylabelText)
p=struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText, ...
 'labels',{{}},'series',struct([]),'z',[],'zShape',[0,0],'clim',[], ...
 'xlabels',{{}},'ylabels',{{}},'ylim',[],'xlim',[],'reference',[],'referenceLabel','','note','');
end
function p=series(p,name,x,y)
s=struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]);
if isempty(p.series), p.series=s; else, p.series(end+1,1)=s; end
end
function specs=figure_spec(specs,name,titleText,rows,cols,panels)
s=struct('name',name,'title',titleText,'rows',rows,'cols',cols,'panels',panels);
if isempty(specs), specs=s; else, specs(end+1,1)=s; end
end
