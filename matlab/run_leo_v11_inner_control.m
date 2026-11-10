function audit = run_leo_v11_inner_control(directory,overrides,render)
%RUN_LEO_V11_INNER_CONTROL 冻结同一代理/权重/旧组，单独比较V8 SB与Local调用。
% 不刷新代理、不运行外层恢复；替换块后仍按原问题检查全员QoS和总服务。
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
saved=load(fullfile(directory,'experiment.mat'),'experiment'); e=saved.experiment; data=e.problemData;
o=struct('resources',unique(round(linspace(1,data.shape(2),min(4,data.shape(2))))),'callBudgetSeconds',2);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
assert(isnumeric(o.resources) && isvector(o.resources) && ~isempty(o.resources));
assert(all(isfinite(o.resources) & o.resources>=1 & o.resources<=data.shape(2) & o.resources==fix(o.resources)));
assert(numel(unique(o.resources))==numel(o.resources));
assert(isscalar(o.callBudgetSeconds) && isfinite(o.callBudgetSeconds) && o.callBudgetSeconds>0);
previous=rng; cleanup=onCleanup(@() rng(previous)); %#ok<NASGU>
if isfield(data.design,'calibrationX')
    reference=data.design.calibrationX;
else
    saved=load(fullfile(directory,'pairs',sprintf('seed_%.0f.mat',e.protocol.seeds(1))),'report');
    reference=saved.report.solutions{1}.initial.x;
end
problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
original=problem.evaluate(reference);
proxy=leo_v8_build_service_surrogates(problem,'current_schedule',reference);
legacy=leo_v8_method_options(); fields=fieldnames(legacy);
for j=1:numel(fields)
    if isfield(e.protocol.method,fields{j}), legacy.(fields{j})=e.protocol.method.(fields{j}); end
end
legacy.verbose=false; solvers={'sb','local'}; runs=struct([]); paired=struct([]);
for caseIndex=1:2
    lambda=zeros(data.shape(1),1);
    if caseIndex==2, lambda=data.qosTargetBits./max(original.userBits,data.qosTargetBits); end
    [weights,~]=leo_price_weights(data,lambda,'throughput',1);
    for m=o.resources(:).'
        qubo=leo_build_resource_qubo(data,proxy.lower,m,weights,legacy);
        for seed=e.protocol.seeds
            outcomes=cell(1,2);
            order=1:2; if mod(find(e.protocol.seeds==seed),2)==0, order=[2,1]; end
            for solverIndex=order
                options=legacy; options.innerSolver=solvers{solverIndex}; options.seed=seed;
                rng(seed,'twister'); budget=struct('timer',tic,'seconds',o.callBudgetSeconds);
                result=leo_v8_solve_resource(data,proxy.lower,m,weights,reference(:,m),options,budget);
                elapsed=toc(budget.timer);
                x=reference; x(:,m)=result.x; service=problem.evaluate(x);
                group=double(result.x(qubo.userIds)); score=qubo.A.'*group-group.'*qubo.B*group/2;
                assert(abs(score-result.score)<1e-10*max(1,abs(score)));
                r=struct('seed',seed,'resource',m,'pricingCase',caseIndex,'solver',solvers{solverIndex}, ...
                    'proxyScore',score,'oldProxyScore',result.oldScore,'callSeconds',elapsed, ...
                    'callBudgetSeconds',o.callBudgetSeconds,'nUserBits',qubo.nUsers,'nQuboBits',qubo.nBits, ...
                    'sbIntegrationSteps',result.sbSteps, ...
                    'originalFullQos',all(service.userBits>=data.qosTargetBits), ...
                    'originalTotalBits',service.totalBits,'originalAcceptedGainBits',0);
                if r.originalFullQos, r.originalAcceptedGainBits=max(0,service.totalBits-original.totalBits); end
                runs=leo_append_struct(runs,r); outcomes{solverIndex}=r;
            end
            a=outcomes{1}; b=outcomes{2};
            r=struct('seed',seed,'resource',m,'pricingCase',caseIndex, ...
                'proxyScoreDelta',a.proxyScore-b.proxyScore, ...
                'originalAcceptedGainDeltaBits',a.originalAcceptedGainBits-b.originalAcceptedGainBits, ...
                'sbCallSeconds',a.callSeconds,'localCallSeconds',b.callSeconds);
            paired=leo_append_struct(paired,r);
        end
    end
end
cases=struct([]);
for caseIndex=1:2
    for m=o.resources(:).'
        selected=paired([paired.resource]==m & [paired.pricingCase]==caseIndex);
        delta=[selected.proxyScoreDelta]; tolerance=1e-10;
        r=struct('resource',m,'pricingCase',caseIndex,'pairedCalls',numel(selected), ...
            'sbProxyWins',sum(delta>tolerance),'proxyTies',sum(abs(delta)<=tolerance), ...
            'localProxyWins',sum(delta<-tolerance),'meanProxyScoreDelta',mean(delta), ...
            'meanOriginalAcceptedGainDeltaBits',mean([selected.originalAcceptedGainDeltaBits]), ...
            'meanSbCallSeconds',mean([selected.sbCallSeconds]),'meanLocalCallSeconds',mean([selected.localCallSeconds]));
        cases=leo_append_struct(cases,r);
    end
end
% 统计单位仍是搜索种子；同一seed的多块调用先平均，不冒充更多独立重复。
seedMeans=struct([]);
for seed=e.protocol.seeds
    selected=paired([paired.seed]==seed);
    r=struct('seed',seed,'cases',numel(selected),'meanProxyScoreDelta',mean([selected.proxyScoreDelta]), ...
        'meanOriginalAcceptedGainDeltaBits',mean([selected.originalAcceptedGainDeltaBits]));
    seedMeans=leo_append_struct(seedMeans,r);
end
audit=struct('version','V11 based on V10','options',o,'searchSeeds',e.protocol.seeds, ...
    'referenceX',reference,'referenceCertifiedBits',original.totalBits,'runs',runs,'pairs',paired, ...
    'cases',cases,'seedMeans',seedMeans, ...
    'scope','One configured inner call under an identical wall-time cap, not a full outer search or proof of exact QUBO optimality.');
leo_write_struct_csv(fullfile(directory,'inner_control_runs.csv'),runs);
leo_write_struct_csv(fullfile(directory,'inner_control_pairs.csv'),paired);
leo_write_struct_csv(fullfile(directory,'inner_control_summary.csv'),cases);
leo_write_struct_csv(fullfile(directory,'inner_control_seed_means.csv'),seedMeans);
save(fullfile(directory,'inner_control.mat'),'audit','-v7');
specs=inner_specs(audit); fid=fopen(fullfile(directory,'v11_inner_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
if render, leo_render_plot_specs(specs,directory); end
fprintf('V11 inner control: %d paired fixed-proxy calls, %d search seeds; original-objective gains exported.\n',numel(paired),numel(e.protocol.seeds));
end
function specs=inner_specs(audit)
c= audit.cases; labels=arrayfun(@(r) sprintf('block %d / price %d',r.resource,r.pricingCase),c,'UniformOutput',false);
p=panel('Fixed-proxy score difference: SB minus Local','Dimensionless weighted proxy score',labels);
p=series(p,'Mean score difference',[c.meanProxyScoreDelta]);
p(2)=panel('Accepted original-service gain difference: SB minus Local','Mbit/period',labels);
p(2)=series(p(2),'Mean accepted gain difference',[c.meanOriginalAcceptedGainDeltaBits]/1e6);
p(3)=panel('Fixed-proxy score wins, ties and losses','Paired calls',labels);
p(3)=series(p(3),'SB wins',[c.sbProxyWins]); p(3)=series(p(3),'Ties',[c.proxyTies]); p(3)=series(p(3),'Local wins',[c.localProxyWins]);
p(4)=panel('One configured inner call: actual elapsed time','Seconds',labels);
p(4)=series(p(4),'SB',[c.meanSbCallSeconds]); p(4)=series(p(4),'Local',[c.meanLocalCallSeconds]);
for j=1:4, p(j).note=audit.scope; end
p(1).reference=0; p(1).referenceLabel='Equal proxy score'; p(2).reference=0; p(2).referenceLabel='Equal accepted original gain';
specs=struct('name','v11_based_on_v10_inner_control','title',sprintf('V11 based on V10 | fixed proxy, weights and initial group | %d search seeds',numel(audit.searchSeeds)), ...
    'rows',2,'cols',2,'panels',p);
end
function p=panel(titleText,ylabelText,labels)
p=struct('kind','categorical_line','title',titleText,'xlabel','Fixed subproblem','ylabel',ylabelText, ...
    'labels',{labels},'series',struct([]),'z',[],'zShape',[0,0],'clim',[], ...
    'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=series(p,name,y)
s=struct('name',name,'x',1:numel(y),'y',y(:).','low',[],'high',[]); p.series=leo_append_struct(p.series,s);
end
