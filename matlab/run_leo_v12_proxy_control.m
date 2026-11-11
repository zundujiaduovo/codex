function audit = run_leo_v12_proxy_control(source,overrides,render)
%RUN_LEO_V12_PROXY_CONTROL 固定代理/权重/旧组，以完整受限域枚举拆分代理和内层损失。
% 受限块诊断不代表32用户完整外层问题；SB调用仍含其原有修复/局部改进。
if nargin<1, source=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
report=leo_v12_load_report(source); data=report.problemData; K=data.shape(1); M=data.shape(2);
directory=fullfile('results','v12_proxy_control');
if ischar(source), if exist(source,'dir')==7, directory=fullfile(source,'proxy_control'); else, directory=fullfile(fileparts(source),'proxy_control'); end; end
o=struct('resources',unique(round(linspace(1,M,min(4,M)))),'maxUsers',12,'maxGroups',100000, ...
    'seeds',report.options.seeds,'callBudgetSeconds',2,'outputDirectory',directory);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
assert(isnumeric(o.resources) && isvector(o.resources) && ~isempty(o.resources) && all(isfinite(o.resources)) && all(o.resources>=1 & o.resources<=M & o.resources==fix(o.resources)) && numel(unique(o.resources))==numel(o.resources));
assert(isnumeric(o.maxUsers) && isscalar(o.maxUsers) && isfinite(o.maxUsers) && o.maxUsers>=1 && o.maxUsers==fix(o.maxUsers));
assert(isnumeric(o.maxGroups) && isscalar(o.maxGroups) && isfinite(o.maxGroups) && o.maxGroups>=1 && o.maxGroups==fix(o.maxGroups));
assert(isscalar(o.callBudgetSeconds) && isfinite(o.callBudgetSeconds) && o.callBudgetSeconds>0);
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds) && all(isfinite(o.seeds) & o.seeds>=0 & o.seeds<=2^32-1 & o.seeds==fix(o.seeds)) && numel(unique(o.seeds))==numel(o.seeds));
directory=o.outputDirectory; if ~exist(directory,'dir'), mkdir(directory); end
before=rng; cleanup=onCleanup(@() rng(before)); %#ok<NASGU>
at=find(strcmp({report.records.method},'sb_v12_lexicographic') & [report.records.seed]==report.options.seeds(1) & strcmp({report.records.status},'completed'),1);
assert(~isempty(at),'A completed SB V12 run for the first requested seed is required.');
refs={report.solutions{at}.initial.x,report.solutions{at}.stage1.x}; refNames={'common_initial','sb_stage1'};
problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
legacy=leo_v8_method_options(); names=fieldnames(legacy);
for j=1:numel(names), if isfield(report.options.method,names{j}), legacy.(names{j})=report.options.method.(names{j}); end; end
legacy.verbose=false; runs=struct([]); exactRows=struct([]); candidateRows=struct([]); weightRows=struct([]);
for ri=1:numel(refs)
    reference=refs{ri}; original=problem.evaluate(reference);
    proxy=leo_v12_build_service_surrogates(problem,'current_schedule',reference);
    for m=o.resources(:).'
        oldIds=find(reference(:,m)); assert(numel(oldIds)<=o.maxUsers,'maxUsers must retain every member of the original group.');
        available=find(data.available(:,m)); [~,order]=sort(original.demandRatio(available),'ascend');
        ids=unique([oldIds;available(order)],'stable'); ids=ids(1:min(o.maxUsers,numel(ids)));
        restricted=data; restricted.available(:,m)=false; restricted.available(ids,m)=true;
        restricted.hard.upper=double(restricted.available(:));
        groups=leo_enumerate_resource_groups(restricted,m,o.maxGroups);
        originalBits=leo_resource_group_services(restricted,m,groups);
        for pi=1:2
            phase='fairness'; lambda=ones(K,1)/K; floorValue=0;
            if pi==2, phase='throughput'; lambda=zeros(K,1); floorValue=original.fairness; end
            weightSource='default_phase_weights';
            history=report.solutions{at}.(sprintf('stage%d',pi)).history;
            if isfield(history,'lambda') && ~isempty(history.lambda)
                lambda=history.lambda(:,end); weightSource='last_recorded_SB_prices';
            end
            [weights,~]=leo_price_weights(data,lambda,phase,floorValue);
            for user=1:K
                entry=struct('reference',refNames{ri},'resource',m,'phase',phase,'user',user, ...
                    'lambda',lambda(user),'serviceWeight',weights(user),'source',weightSource);
                weightRows=leo_append_struct(weightRows,entry);
            end
            q=leo_build_resource_qubo(restricted,proxy.lower,m,weights,legacy);
            z=double(groups(q.userIds,:)); proxyScores=q.A.'*z-sum(z.*(q.B*z),1)/2;
            originalScores=weights.'*originalBits;
            tolerance=1e-9*max(1,max(abs(originalScores)));
            assert(all(proxyScores<=originalScores+tolerance),'Quadratic lower service exceeds the original weighted service.');
            [pstar,px]=max(proxyScores); [astar,ax]=max(originalScores);
            row=struct('reference',refNames{ri},'resource',m,'phase',phase,'nAvailableUsers',numel(available), ...
                'weightSource',weightSource, ...
                'nDomainUsers',numel(ids),'domainRestricted',numel(ids)<numel(available),'legalGroups',size(groups,2), ...
                'exactOriginalWeightedScore',astar,'exactProxyWeightedScore',pstar, ...
                'originalScoreAtExactProxy',originalScores(px),'proxyOptimumValueGap',max(0,astar-pstar), ...
                'surrogateArgmaxOriginalLoss',max(0,astar-originalScores(px)), ...
                'surrogateArgmaxOriginalLossPercent',percent(astar-originalScores(px),astar), ...
                'scope','Exact enumeration on this explicitly restricted block domain, fixed reference and weights. Not full-problem max-min loss.');
            exactRows=leo_append_struct(exactRows,row);
            candidateRows=save_group(candidateRows,refNames{ri},m,phase,'exact_original',0,ids,groups(:,ax));
            candidateRows=save_group(candidateRows,refNames{ri},m,phase,'exact_proxy',0,ids,groups(:,px));
            for si=1:numel(o.seeds)
                seed=o.seeds(si); order=1:2; if mod(si,2)==0, order=[2,1]; end
                solvers={'sb','local'};
                for solver=order
                    options=legacy; options.innerSolver=solvers{solver}; options.seed=seed;
                    rng(seed,'twister'); budget=struct('timer',tic,'seconds',o.callBudgetSeconds);
                    inner=leo_v8_solve_resource(restricted,proxy.lower,m,weights,reference(:,m),options,budget);
                    elapsed=toc(budget.timer); g=double(inner.x(q.userIds)); pscore=q.A.'*g-g.'*q.B*g/2;
                    assert(abs(pscore-inner.score)<=tolerance && pscore<=pstar+tolerance);
                    oscore=weights.'*leo_resource_service(restricted,m,inner.x);
                    assert(oscore<=astar+tolerance);
                    schedule=reference; schedule(:,m)=inner.x; service=leo_evaluate_service(restricted,schedule);
                    row=struct('reference',refNames{ri},'resource',m,'phase',phase,'seed',seed,'solver',solvers{solver}, ...
                        'nDomainUsers',numel(ids),'nQuboBits',q.nBits,'domainRestricted',numel(ids)<numel(available), ...
                        'exactProxyScore',pstar,'proxyScore',pscore,'innerProxyLoss',max(0,pstar-pscore), ...
                        'innerProxyLossOverOriginalOptimumPercent',percent(pstar-pscore,astar), ...
                        'exactOriginalScore',astar,'originalWeightedScore',oscore, ...
                        'combinedOriginalLossPercent',percent(astar-oscore,astar), ...
                        'combinedLossUpperBoundPercent',percent(astar-pscore,astar), ...
                        'originalFairness',service.fairness,'originalTotalBits',service.totalBits, ...
                        'wouldAcceptOriginal',leo_service_is_better(service,original,phase,floorValue), ...
                        'deltaOriginalFairness',service.fairness-original.fairness,'deltaOriginalTotalBits',service.totalBits-original.totalBits, ...
                        'callSeconds',elapsed,'callBudgetSeconds',o.callBudgetSeconds,'sbIntegrationSteps',inner.sbSteps, ...
                        'denseDynamicsTerms',inner.nBits^2*inner.sbSteps*options.sbTrajectories);
                    runs=leo_append_struct(runs,row);
                    candidateRows=save_group(candidateRows,refNames{ri},m,phase,solvers{solver},seed,ids,inner.x);
                end
            end
        end
    end
end
audit=struct('version','V12 fixed-proxy exact block audit 1','options',o,'referenceNames',{refNames}, ...
    'referenceSchedules',{refs},'exact',exactRows,'runs',runs,'groups',candidateRows,'weights',weightRows, ...
    'problemDataSnapshot',data,'scope','Restricted block domains; exact proxy/original optima and paired SB/Local calls, with no outer refresh or recovery.');
referenceRows=struct([]);
for ri=1:numel(refs)
    for user=1:K
        for m=1:M
            entry=struct('reference',refNames{ri},'user',user,'resource',m,'selected',refs{ri}(user,m));
            referenceRows=leo_append_struct(referenceRows,entry);
        end
    end
end
leo_write_struct_csv(fullfile(directory,'exact_proxy_original_comparison.csv'),exactRows);
leo_write_struct_csv(fullfile(directory,'fixed_proxy_inner_runs.csv'),runs);
leo_write_struct_csv(fullfile(directory,'fixed_proxy_selected_groups.csv'),candidateRows);
leo_write_struct_csv(fullfile(directory,'fixed_proxy_weights.csv'),weightRows);
leo_write_struct_csv(fullfile(directory,'fixed_proxy_reference_schedules.csv'),referenceRows);
leo_export_proxy_audit(report,directory,24);
save(fullfile(directory,'proxy_control.mat'),'audit','-v7');
specs=make_specs(audit); fid=fopen(fullfile(directory,'v12_proxy_control_specs.json'),'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
if render, leo_render_plot_specs(specs,directory); end
fprintf('V12 proxy control: %d exact block/weight cases, %d paired SB/Local calls; restricted domains explicitly marked.\n',numel(exactRows),numel(runs)/2);
end
function rows=save_group(rows,referenceName,m,phase,solver,seed,ids,group)
entry=struct('reference',referenceName,'resource',m,'phase',phase,'seed',seed,'solver',solver, ...
    'domainUsers',strtrim(sprintf('%d ',ids)),'selectedMask',char(double(group(:).')+'0'));
rows=leo_append_struct(rows,entry);
end
function value=percent(loss,scale)
value=NaN; if scale>0, value=100*max(0,loss)/scale; end
end
function specs=make_specs(audit)
e=audit.exact; labels=arrayfun(@(r) sprintf('%s/b%d/%s',r.reference,r.resource,r.phase),e,'UniformOutput',false);
p=panel('Original weighted loss from the exact proxy argmax','Percent of exact original weighted optimum',labels);
p=add(p,'Exact proxy chosen group',[e.surrogateArgmaxOriginalLossPercent]);
p(2)=panel('Inner proxy solve loss on the same fixed domain','Percent of exact original weighted optimum',labels);
p(3)=panel('Combined original weighted loss after each inner call','Percent of exact original weighted optimum',labels);
p(4)=panel('Actual configured inner-call time','Seconds',labels);
for solver={'sb','local'}
    label='SB'; if strcmp(solver{1},'local'), label='Local'; end
    values=NaN(3,numel(e));
    for j=1:numel(e)
        rows=audit.runs(strcmp({audit.runs.solver},solver{1}) & strcmp({audit.runs.reference},e(j).reference) & [audit.runs.resource]==e(j).resource & strcmp({audit.runs.phase},e(j).phase));
        values(:,j)=[median([rows.innerProxyLossOverOriginalOptimumPercent]);median([rows.combinedOriginalLossPercent]);median([rows.callSeconds])];
    end
    p(2)=add(p(2),label,values(1,:)); p(3)=add(p(3),label,values(2,:)); p(4)=add(p(4),label,values(3,:));
end
for j=1:4, p(j).note=audit.scope; end
specs=struct('name','v12_proxy_control','title','V12 exact proxy/original BLOCK diagnostics | restricted domains explicitly declared','rows',2,'cols',2,'panels',p);
end
function p=panel(titleText,ylabelText,labels)
p=struct('kind','categorical_line','title',titleText,'xlabel','Frozen block/weight case','ylabel',ylabelText,'labels',{labels}, ...
    'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=add(p,name,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',1:numel(y),'y',y(:).','low',[],'high',[]));
end
