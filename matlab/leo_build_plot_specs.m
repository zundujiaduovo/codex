function figures = leo_build_plot_specs(data)
%LEO_BUILD_PLOT_SPECS 生成完整图组的数值规格，MATLAB/Python 共用同一数据和口径。
% 输入：leo_collect_plot_data 输出；输出：图名、子图、曲线、误差范围、热图等结构数组。
% 柱为多种子中位数，误差棒为最小至最大；非置信区间。缺失值保持 NaN。
figures = struct([]); records = data.records; counts = data.counts;
methods = data.methods; good = {};
for j = 1:numel(methods)
    if any(strcmp({records.method},methods{j}) & strcmp({records.status},'completed'))
        good{end+1} = methods{j}; %#ok<AGROW>
    end
end
stamp = sprintf('%s | K=%d, M=%d, L=%d | median and min-max across %d seeds', ...
    data.caseName,data.shape(1),data.shape(2),data.maxStreams,numel(data.seeds));
repStamp = sprintf('%s | first requested seed %d',data.caseName,data.representativeSeed);
if isfield(data,'serviceModel') && any(strcmp(data.serviceModel,{'periodic_chernoff','periodic_multilevel'}))
    stamp = [stamp,' | certified period service'];
    repStamp = [repStamp,' | certified period service'];
end

p = metric(records,good,'fairness',1,'Capped minimum QoS ratio','Fairness');
p(2) = metric(records,good,'totalBits',1e-6,'Diagnostic certified service (all returned schedules)','Mbit');
if isfield(data,'requireFullQos') && data.requireFullQos
    p(2)=metric(records,good,'feasibleTotalBits',1e-6,'Certified service ONLY for full-QoS schedules','Mbit');
end
p(3) = metric(records,good,'qosSatisfactionRate',100,'Users meeting full QoS','Percent');
p(4) = metric(records,good,'worstDemandRatio',1,'Minimum uncapped demand ratio','Service / target');
if ~isempty(data.reference) && data.reference.optimal
    p(1).reference = data.reference.fairness; p(1).referenceLabel = 'Exhaustive optimum';
end
figures = add_figure(figures,'01_performance',stamp,2,2,p);

p = metric(records,good,'endToEndSeconds',1,'Accounted end-to-end time','Seconds');
p(1).reference = data.budgetSeconds; p(1).referenceLabel = 'Soft budget';
p(2) = metric(records,good,{'commonSeconds','proxyPreparationSeconds','searchSeconds'},1, ...
    'Timing components (internal proxy work stays in search)','Seconds');
p(3) = metric(records,good,'budgetOverrunSeconds',1,'Actual budget overrun (not clipped)','Seconds');
p(4) = metric(counts,good,'proxyRefreshes',1,'Proxy refresh count','Refreshes');
figures = add_figure(figures,'02_runtime',stamp,2,2,p);

p = metric(counts,good,{'priceRounds1','priceRounds2'},1,'Price rounds attempted, including partial','Price rounds');
complete = counts;
for j = 1:numel(complete)
    complete(j).complete = counts(j).completeRounds1+counts(j).completeRounds2;
    complete(j).partial = counts(j).priceRounds1+counts(j).priceRounds2-complete(j).complete;
end
p(2) = metric(complete,good,{'complete','partial'},1,'Complete versus partial price rounds','Price rounds');
p(3) = metric(counts,{'original_greedy'}, {'searchSteps1','searchSteps2'},1,'Greedy accepted additions','Accepted additions');
p(4) = metric(counts,{'original_exchange','original_tabu'}, {'searchSteps1','searchSteps2'},1,'Original-objective neighborhood rounds','Search rounds');
p(5) = metric(counts,{'proxy_milp'},{'nodes1','nodes2'},1,'MILP branch-and-bound nodes','Nodes');
p(5).note = 'GLPK does not report node counts; missing values are not zero.';
p(6) = metric(counts,{'proxy_milp'},'milpCalls',1,'MILP solver invocations (separate unit)','Calls');
figures = add_figure(figures,'03_iterations',stamp,3,2,p);

p = metric(counts,good,'sbIntegrationSteps',1,'SB integration steps summed over all calls','Steps');
p(2) = metric(counts,good,'sbTrajectorySteps',1,'SB steps multiplied by trajectory count','Trajectory-steps');
p(3) = metric(counts,good,'resourceSolves',1,'Resource subproblems solved','Calls');
p(4) = metric(counts,good,'repairedCandidates',1,'Candidates changed by hard repair','Candidates');
p(5) = metric(counts,good,{'recoveryEvaluations','crossEvaluations'},1,'Recovery evaluations (cross is a subset)','Evaluations');
p(6) = metric(counts,good,'originalEvaluations',1,'Original baseline search evaluations','Evaluations');
figures = add_figure(figures,'04_search_work',stamp,3,2,p);

p = history_curves(data,1,'fairness',1,'Saved original fairness: phase 1','Fairness');
p(2) = history_curves(data,1,'totalBits',1e-6,'Diagnostic service: feasibility search (may decrease)','Mbit');
p(3) = history_curves(data,2,'fairness',1,'Saved original fairness: phase 2','Fairness');
p(4) = history_curves(data,2,'totalBits',1e-6,'Saved throughput: phase 2','Mbit');
figures = add_figure(figures,'05_price_convergence',[repStamp,' | price methods; portfolio branches excluded'],2,2,p);

p = time_curves(data,good,'fairness',1,'Original fairness versus accounted time','Fairness');
p(2) = time_curves(data,good,'totalBits',1e-6,'Diagnostic service versus accounted time (check full QoS)','Mbit');
figures = add_figure(figures,'06_time_convergence',[repStamp,' | recorded checkpoints; no solver-internal interpolation'],2,1,p);

p = metric(records,good,'fairnessGap',1,'Valid original fairness bound minus achieved value','Absolute fairness gap');
p(2) = metric(records,good,'throughputGapBits',1e-6,'Valid throughput gap at the recorded required floor','Mbit');
p(3) = metric(records,good,'exactFairnessGap',1,'Gap to exhaustive fairness optimum','Absolute fairness gap');
p(4) = metric(records,good,'exactThroughputGapBits',1e-6,'Exact throughput gap ONLY at exact fairness floor','Mbit');
p(3).note = 'Only a completed exhaustive search supplies an exact reference.';
p(4).note = 'Different fairness floors are not comparable; these entries remain missing.';
figures = add_figure(figures,'07_optimality_gaps',stamp,2,2,p);

p = bound_curve(data,1); p(2) = bound_curve(data,2);
p(3) = history_curves(data,1,'gap',1,'Valid fairness gap during price search','Absolute gap');
p(4) = history_curves(data,2,'gap',1e-6,'Valid throughput gap during price search','Mbit');
figures = add_figure(figures,'08_bound_convergence',repStamp,2,2,p);

p = price_heatmap(data,1,'lambda','Phase 1 nonnegative user prices');
p(2) = price_heatmap(data,2,'lambda','Phase 2 nonnegative user prices');
p(3) = price_heatmap(data,1,'lowerDemandRatio','Phase 1 lower service / target (unclipped)');
p(4) = price_heatmap(data,2,'lowerDemandRatio','Phase 2 lower service / target (unclipped)');
figures = add_figure(figures,'09_price_feedback',[repStamp,' | Price+SB'],2,2,p);

p = panel('heatmap','Every user original demand ratio','User','Method');
p.z = NaN(numel(data.representatives),data.shape(1));
p.ylabels = cell(1,numel(data.representatives));
for j = 1:numel(data.representatives)
    rep = data.representatives(j); p.z(j,:) = rep.service.demandRatio;
    p.ylabels{j} = short_name(rep.method);
end
p(2) = panel('line','Empirical CDF of user demand ratios','Original service / target','Fraction of users');
p(2).reference = []; p(2).ylim = [0,1];
for j = 1:numel(data.representatives)
    rep = data.representatives(j); values = sort(rep.service.demandRatio);
    p(2) = series(p(2),short_name(rep.method),values,(1:numel(values))/numel(values));
end
rep = main_rep(data);
p(3) = panel('bar','Price+SB service and full QoS target','User','Mbit');
p(4) = panel('line','Price+SB per-user service across phases','User','Mbit');
if ~isempty(rep)
    p(3).labels = number_labels(data.shape(1));
    p(3) = series(p(3),'Achieved',1:data.shape(1),rep.service.userBits/1e6);
    p(3) = series(p(3),'QoS target',1:data.shape(1),data.targetBits/1e6);
    p(4) = series(p(4),'Initial',1:data.shape(1),rep.initial.userBits/1e6);
    p(4) = series(p(4),'Phase 1',1:data.shape(1),rep.stage1.userBits/1e6);
    p(4) = series(p(4),'Phase 2',1:data.shape(1),rep.service.userBits/1e6);
end
figures = add_figure(figures,'10_user_service',repStamp,2,2,p);

p = repmat(panel('heatmap','','Fixed time block','User'),1,0);
for j = 1:numel(data.representatives)
    rep = data.representatives(j);
    p(j) = panel('heatmap',short_name(rep.method),'Fixed time block','User');
    p(j).z = double(rep.x); p(j).clim = [0,1];
end
if isempty(p), p = panel('heatmap','No completed schedules','Block','User'); end
figures = add_figure(figures,'11_schedules',[repStamp,' | 1=selected, 0=idle; one decision per fixed block'],ceil(numel(p)/3),3,p);

p = panel('line','Concurrent users per fixed block','Block','Users');
p.reference = data.maxStreams; p.referenceLabel = 'Concurrent-user limit'; p.ylim = [0,data.maxStreams+1];
p(2) = panel('line','Additive service before period risk margin','Block','Mbit');
p(3) = panel('heatmap','Price+SB use of the fixed beam codebook','Block','Beam');
p(3).clim = [0,1];
p(4) = panel('line','Design SINR CDF for active data samples','Design SINR (dB)','Fraction of active samples');
for j = 1:numel(data.representatives)
    rep = data.representatives(j);
    p(1) = series(p(1),short_name(rep.method),1:data.shape(2),sum(rep.x,1));
    p(2) = series(p(2),short_name(rep.method),1:data.shape(2),sum(rep.service.resourceBits,1)/1e6);
    v = sort(10*log10(rep.service.gamma(rep.service.gamma>0)));
    if ~isempty(v), p(4) = series(p(4),short_name(rep.method),v,(1:numel(v))/numel(v)); end
end
rep = main_rep(data);
if ~isempty(rep)
    p(3).z = zeros(data.nBeams,data.shape(2));
    for m = 1:data.shape(2), p(3).z(data.beamIndex(rep.x(:,m),m),m) = 1; end
end
figures = add_figure(figures,'12_resources_and_sinr',repStamp,2,2,p);

p = seed_points(data,good,'fairness',1,'Fairness for every seed','Fairness');
p(2) = seed_points(data,good,'totalBits',1e-6,'Throughput for every seed','Mbit');
p(3) = seed_points(data,good,'endToEndSeconds',1,'Time for every seed','Seconds');
p(4) = panel('scatter','Quality versus time (every completed run)','Accounted time (s)','Fairness');
for j = 1:numel(good)
    rows = records(strcmp({records.method},good{j}) & strcmp({records.status},'completed'));
    p(4) = series(p(4),short_name(good{j}),[rows.endToEndSeconds],[rows.fairness]);
end
figures = add_figure(figures,'13_seed_variation',stamp,2,2,p);

p = energy_curve(data,1); p(2) = energy_curve(data,2);
figures = add_figure(figures,'14_sb_energy',[repStamp,' | first Price+SB Ising call per phase; before hard repair'],1,2,p);

p = panel('line','Fixed minimax tangent / original rate / chord','Interference / legal maximum','Mbit/s');
p(2) = panel('line','Rate approximation error over legal interval','Interference / legal maximum','Mbit/s');
if isfield(data.approximation,'originalMbps')
    a = data.approximation;
    p(1).title = sprintf('Rate bounds, first nonzero interval: user %d, sample %d',a.user,a.slot);
    p(1) = series(p(1),'Original',a.normalizedInterference,a.originalMbps);
    p(1) = series(p(1),'Tangent lower',a.normalizedInterference,a.lowerMbps);
    p(1) = series(p(1),'Chord upper',a.normalizedInterference,a.upperMbps);
    p(2) = series(p(2),'Original - tangent',a.normalizedInterference,a.originalMbps-a.lowerMbps);
    p(2) = series(p(2),'Chord - original',a.normalizedInterference,a.upperMbps-a.originalMbps);
end
p(3) = panel('line','Price+SB final schedule: fixed minimax service bounds','User','Mbit');
p(4) = panel('line','Observed lower error and certified error allowance','User','Mbit');
if ~isempty(data.serviceBounds)
    index = find(strcmp({data.serviceBounds.method},'price_sb'),1);
    if ~isempty(index)
        b = data.serviceBounds(index); users = 1:data.shape(1);
        p(3) = series(p(3),'Tangent lower',users,b.lowerBits/1e6);
        p(3) = series(p(3),'Original',users,b.originalBits/1e6);
        p(3) = series(p(3),'Chord upper',users,b.upperBits/1e6);
        p(4) = series(p(4),'Observed original - lower',users,(b.originalBits-b.lowerBits)/1e6);
        p(4) = series(p(4),'Certified allowance',users,b.lowerErrorBoundBits/1e6);
    end
end
figures = add_figure(figures,'15_tangent_chord',repStamp,2,2,p);

ablations = intersect({'price_sb','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'},good,'stable');
p = metric(records,ablations,'fairness',1,'Reference-point ablation: original fairness','Fairness');
p(2) = metric(records,ablations,'totalBits',1e-6,'Reference-point ablation: original throughput','Mbit');
p(3) = metric(records,ablations,'endToEndSeconds',1,'Reference-point ablation: actual accounted time','Seconds');
p(4) = metric(counts,ablations,'sbIntegrationSteps',1,'All SB work, including all portfolio members','SB integration steps');
figures = add_figure(figures,'16_reference_ablation',stamp,2,2,p);

p = panel('heatmap','Method execution status across seeds','Seed','Method');
p.z = NaN(numel(methods),numel(data.seeds)); p.clim = [0,3];
p.ylabels = cellfun(@short_name,methods,'UniformOutput',false); p.xlabels = arrayfun(@num2str,data.seeds,'UniformOutput',false);
p.note = '0=unavailable, 1=budget exhausted before search, 2=failed, 3=completed (may stop at time limit)';
for j = 1:numel(methods)
    for k = 1:numel(data.seeds)
        index = find(strcmp({records.method},methods{j}) & [records.seed]==data.seeds(k),1);
        if isempty(index), continue; end
        status = records(index).status;
        if strcmp(status,'completed'), code = 3;
        elseif strcmp(status,'unavailable'), code = 0;
        elseif strcmp(status,'budget_exhausted_before_search'), code = 1;
        else, code = 2; end
        p.z(j,k) = code;
    end
end
p(2) = panel('heatmap','Physical availability (all candidates, before scheduling)','Block','User');
p(2).z = double(data.available); p(2).clim = [0,1];
figures = add_figure(figures,'17_status_and_availability',repStamp,1,2,p);

p = panel('bar','Fairness at common initialization and each saved phase','Method','Fairness');
p(2) = panel('bar','Throughput at each phase (fairness is prioritized)','Method','Mbit');
names = {}; if ~isempty(data.representatives), names = {data.representatives.method}; end
for j = 1:2, p(j).labels = cellfun(@short_name,names,'UniformOutput',false); end
for stage = 1:3
    f = zeros(1,numel(names)); v = f; stageNames = {'Initial','Phase 1','Phase 2'};
    for j = 1:numel(names)
        rep = data.representatives(j);
        if stage==1, s = rep.initial; elseif stage==2, s = rep.stage1; else, s = rep.service; end
        f(j) = s.fairness; v(j) = s.totalBits/1e6;
    end
    p(1) = series(p(1),stageNames{stage},1:numel(names),f);
    p(2) = series(p(2),stageNames{stage},1:numel(names),v);
end
figures = add_figure(figures,'18_phase_results',repStamp,2,1,p);
% JSON 编码可能把单行/单列矩阵压成向量，显式保留二维形状。
for j = 1:numel(figures)
    for k = 1:numel(figures(j).panels)
        figures(j).panels(k).zShape = size(figures(j).panels(k).z);
    end
end
end

function p = panel(kind,titleText,xlabelText,ylabelText)
p = struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText, ...
    'labels',{{}},'series',struct([]),'z',[],'zShape',[],'clim',[],'xlabels',{{}},'ylabels',{{}}, ...
    'ylim',[],'reference',[],'referenceLabel','','note','');
end

function p = series(p,name,x,y,low,high)
if nargin<5, low = []; high = []; end
s = struct('name',name,'x',x(:).','y',y(:).','low',low(:).','high',high(:).');
if isempty(p.series), p.series = s; else, p.series(end+1,1) = orderfields(s,p.series); end
end

function p = metric(rows,methods,fields,scale,titleText,unit)
if ischar(fields), fields = {fields}; end
p = panel('bar',titleText,'Method',unit);
p.labels = cellfun(@short_name,methods,'UniformOutput',false);
for f = 1:numel(fields)
    y = NaN(1,numel(methods)); lo = y; hi = y;
    for j = 1:numel(methods)
        subset = rows(strcmp({rows.method},methods{j}) & strcmp({rows.status},'completed'));
        if isempty(subset), continue; end
        v = [subset.(fields{f})]*scale; v = v(isfinite(v));
        if isempty(v), continue; end
        y(j) = median(v); lo(j) = min(v); hi(j) = max(v);
    end
    p = series(p,strrep(fields{f},'_',' '),1:numel(methods),y,lo,hi);
end
end

function figures = add_figure(figures,name,titleText,nrows,ncols,panels)
fig = struct('name',name,'title',titleText,'rows',nrows,'cols',ncols,'panels',panels);
if isempty(figures), figures = fig; else, figures(end+1,1) = orderfields(fig,figures); end
end

function p = history_curves(data,phase,field,scale,titleText,unit)
p = panel('line',titleText,'Price round (partial final round included)',unit);
for j = 1:numel(data.methods)
    rows = price_events(data,data.methods{j},phase);
    if isempty(rows), continue; end
    if strcmp(field,'gap')
        if phase==1, value = [rows.upperBound]-[rows.fairness];
        else, value = [rows.upperBound]-[rows.totalBits]; end
    else, value = [rows.(field)]; end
    p = series(p,short_name(data.methods{j}),[rows.iteration],value*scale);
end
end

function rows = price_events(data,method,phase)
rows = struct([]); if isempty(data.events), return; end
rows = data.events(strcmp({data.events.method},method) & [data.events.seed]==data.representativeSeed & ...
    strcmp({data.events.member},'main') & [data.events.phase]==phase & isfinite([data.events.upperBound]));
end

function p = time_curves(data,methods,field,scale,titleText,unit)
p = panel('step',titleText,'Accounted elapsed time (s)',unit);
for j = 1:numel(methods)
    rows = data.progress(strcmp({data.progress.method},methods{j}) & [data.progress.seed]==data.representativeSeed);
    if isempty(rows), continue; end
    [~,order] = sort([rows.seconds]); rows = rows(order);
    p = series(p,short_name(methods{j}),[rows.seconds],[rows.(field)]*scale);
end
end

function p = bound_curve(data,phase)
if phase==1, unit = 'Fairness'; scale = 1; field = 'fairness';
else, unit = 'Mbit at fixed phase-2 floor'; scale = 1e-6; field = 'totalBits'; end
p = panel('line',sprintf('Price+SB valid original bounds: phase %d',phase),'Price round',unit);
rows = price_events(data,'price_sb',phase);
if isempty(rows), return; end
p = series(p,'Saved feasible original value',[rows.iteration],[rows.(field)]*scale);
p = series(p,'Valid original upper bound',[rows.iteration],[rows.upperBound]*scale);
end

function p = price_heatmap(data,phase,field,titleText)
p = panel('heatmap',titleText,'Price round','User');
if isempty(data.prices), return; end
rows = data.prices(strcmp({data.prices.method},'price_sb') & [data.prices.seed]==data.representativeSeed & ...
    strcmp({data.prices.member},'main') & [data.prices.phase]==phase);
if isempty(rows), return; end
p.z = NaN(data.shape(1),max([rows.iteration]));
for k = 1:numel(rows), p.z(rows(k).user,rows(k).iteration) = rows(k).(field); end
if strcmp(field,'lambda')
    highest = max(p.z(:)); if highest==0, highest = 1; end
    p.clim = [0,highest];
end
end

function p = seed_points(data,methods,field,scale,titleText,unit)
p = panel('scatter',titleText,'Requested seed (index)',unit);
for j = 1:numel(methods)
    rows = data.records(strcmp({data.records.method},methods{j}) & strcmp({data.records.status},'completed'));
    [~,positions] = ismember([rows.seed],data.seeds);
    p = series(p,short_name(methods{j}),positions,[rows.(field)]*scale);
end
p.xlabels = arrayfun(@num2str,data.seeds,'UniformOutput',false);
end

function p = energy_curve(data,phase)
p = panel('line',sprintf('Phase %d: fixed Ising call, best-so-far energy',phase),'SB integration step','Discrete Ising energy');
p.note = 'Different phases solve different Ising problems; their energy values are not comparable.';
if isempty(data.energy), return; end
rows = data.energy(strcmp({data.energy.method},'price_sb') & [data.energy.seed]==data.representativeSeed & ...
    strcmp({data.energy.member},'main') & [data.energy.phase]==phase);
if isempty(rows), return; end
p.title = sprintf('Phase %d: resource %d, price round %d, %d trajectories', ...
    phase,rows(1).resource,rows(1).priceIteration,rows(1).trajectories);
p = series(p,'Best trajectory',[rows.step],[rows.minimum]);
p = series(p,'Median trajectory',[rows.step],[rows.median]);
p = series(p,'Worst trajectory',[rows.step],[rows.maximum]);
end

function rep = main_rep(data)
rep = []; if isempty(data.representatives), return; end
index = find(strcmp({data.representatives.method},'price_sb'),1);
if ~isempty(index), rep = data.representatives(index); end
end

function labels = number_labels(n)
labels = arrayfun(@num2str,1:n,'UniformOutput',false);
end

function name = short_name(name)
names = {'initial','original_greedy','original_exchange','original_tabu','price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local','price_local_adaptive', ...
    'price_miqp','proxy_milp','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
labels = {'Initial','Greedy','Exchange','Tabu','Price+SB','SB: block','SB: adapt','SB: light','Price+Local','Local: adapt','Price+MIQP','Proxy MILP', ...
    'SB: zero','SB: minimax','SB: current','SB: portfolio'};
index = find(strcmp(names,name),1); if ~isempty(index), name = labels{index}; end
end
