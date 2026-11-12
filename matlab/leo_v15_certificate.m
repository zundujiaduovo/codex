function certificate=leo_v15_certificate(report,directory,phase,floorValue,overrides)
% Original-service branch-and-price with resumable certified block pricing.
% No quadratic proxy enters the bound. Interrupted pricing uses ALL open-node
% upper bounds. Restricted-master primal values are never treated as global U.
% Floating point certificate to explicit outward guards, not exact arithmetic.
if nargin<3, phase='fairness'; end
if nargin<4, floorValue=0; end
if nargin<5, overrides=struct(); end
o=leo_v15_bound_options(overrides); d=report.problemData;
assert(leo_is_lexicographic(d) && any(strcmp(phase,{'fairness','throughput'})));
assert(isscalar(floorValue) && isfinite(floorValue) && floorValue>=0);
assert(~strcmp(phase,'throughput') || floorValue>0,'V15 conditional throughput requires a strictly positive stated fairness floor.');
if ~exist(directory,'dir'), mkdir(directory); end
path=fullfile(directory,'checkpoint.mat'); K=d.shape(1); M=d.shape(2);
started=tic; sessionSweeps=0; sessionNodes=0;
if exist(path,'file')==2
    saved=load(path,'state'); state=saved.state;
    assert(state.schemaVersion==1 && isequaln(state.problemData,d) && strcmp(state.phase,phase) && state.floor==floorValue, ...
        'V15 certificate checkpoint has a different model/objective/floor. Use another directory.');
    assert(state.arithmeticGuard==o.arithmeticGuard && state.pricingTolerance==o.pricingTolerance, ...
        'Changing arithmetic/pricing tolerance requires a new certificate directory. Work limits and gap targets may change.');
else
    state=initialize();
end
previousSeconds=state.elapsedSeconds;
% Revalidate and include all newly supplied feasible schedules on every resume.
schedules={false(K,M)};
for j=1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed') || isempty(report.solutions{j}), continue; end
    solution=report.solutions{j}; schedules{end+1}=solution.x; %#ok<AGROW>
    if isfield(solution,'stage1'), schedules{end+1}=solution.stage1.x; end %#ok<AGROW>
end
if isfield(report,'fairnessCertificate') && ~isempty(report.fairnessCertificate.incumbentX)
    assert(isequaln(report.fairnessCertificate.problemDataSnapshot,d));
    schedules{end+1}=report.fairnessCertificate.incumbentX;
end
for j=1:numel(schedules), consider(schedules{j}); add_schedule(schedules{j}); end
if ~isempty(state.incumbentX), consider(state.incumbentX); end
if state.sweeps==0 && state.blockCalls==0, state.initialLower=state.lower; end
fprintf('\nORIGINAL %s certificate; floor %.12g. Target gap %.4g%%.\n',phase,floorValue,100*o.relativeGap);
fprintf('Per block: true log(1+SINR), common active beams, at most %d users; no quadratic proxy.\n',d.maxStreams);
if strcmp(phase,'fairness')
    fprintf('U(lambda)=max(0, S_cap*[1-sum(lambda)]_+ + sum_m H_m^UB(lambda/q) - sum_i lambda_i*c_i/q_i).\n');
else
    fprintf('U(mu)=sum_m H_m^UB(1+mu*1e6/q) - sum_i c_i/1e6 - sum_i mu_i*(s0+c_i/q_i), in Mbit.\n');
end
fprintf('H_m^UB covers every legal original-model group and every unsearched pricing branch.\n');
state.status='work_limit_unclosed'; checkpoint();
while sessionSweeps<o.maxSweeps && toc(started)<o.maxSeconds
    if met(), state.status='gap_target_met'; break; end
    if isempty(state.active)
        if isempty(state.queue), state.status='all_schedule_branches_closed'; break; end
        if sessionNodes>=o.maxBranchNodes, state.status='branch_node_limit_unclosed'; break; end
        [~,at]=max(cellfun(@(x)x.upper,state.queue)); node=state.queue{at}; state.queue(at)=[];
        if node.upper<=state.lower
            state.closedUpper=max(state.closedUpper,node.upper); checkpoint(); continue;
        end
        if ~node.visited
            node.visited=true; state.nodesProcessed=state.nodesProcessed+1; sessionNodes=sessionNodes+1;
        end
        if ~any(node.fixed(:)==-1)
            x=node.fixed==1;
            if legal(x)
                service=leo_evaluate_service(d,x); consider(x); value=objective(service);
                state.closedUpper=max(state.closedUpper,value);
            end
            checkpoint(); continue;
        end
        cap=leo_fairness_limit(d); if strcmp(phase,'fairness'), cap=min(cap,node.upper); end
        master=leo_v15_master(d,state.pool,node.fixed,phase,floorValue,cap,o);
        if master.hardInfeasible, checkpoint(); continue; end
        state.active=struct('node',node,'master',master,'pricingStates',{cell(1,M)}, ...
            'supportUpper',Inf(1,M),'supportLower',-Inf(1,M),'complete',false(1,M), ...
            'groups',false(K,M),'nextBlock',1,'passes',0);
    end
    stopped=false;
    for m=state.active.nextBlock:M
        if toc(started)>=o.maxSeconds, stopped=true; break; end
        state.active.nextBlock=m;
        if state.active.complete(m), state.active.nextBlock=m+1; continue; end
        a=state.active;
        [priced,pricingState]=leo_v15_price_block(d,m,a.master.weights,a.node.fixed(:,m),o,a.pricingStates{m},state.pool.groups{m});
        state.active.pricingStates{m}=pricingState;
        state.active.supportUpper(m)=min(a.supportUpper(m),priced.upper);
        state.active.supportLower(m)=priced.lower; state.active.complete(m)=priced.complete;
        state.active.groups(:,m)=priced.group; state.active.nextBlock=m+1;
        state.pricingNodes=state.pricingNodes+priced.expanded; state.blockCalls=state.blockCalls+1;
        row=struct('call',state.blockCalls,'scheduleNode',a.node.id,'resource',m, ...
            'supportLower',priced.lower,'supportUpper',priced.upper,'pricingComplete',priced.complete, ...
            'expanded',priced.expanded,'openPricingNodes',priced.openNodes,'status',priced.status);
        state.pricingTrace=leo_append_struct(state.pricingTrace,row);
        if o.verbose
            fprintf('Certificate %s node %d block %d/%d: H in [%.8g, %.8g], open=%d, %s.\n', ...
                phase,a.node.id,m,M,priced.lower,priced.upper,priced.openNodes,priced.status);
        end
        checkpoint();
    end
    if stopped, state.status='time_limit_unclosed'; break; end
    a=state.active; state.sweeps=state.sweeps+1; sessionSweeps=sessionSweeps+1;
    if any(a.supportUpper==-Inf)
        state.active=[]; checkpoint(); continue;
    end
    candidate=sum(a.supportUpper)+a.master.constant;
    if strcmp(phase,'fairness'), candidate=max(0,candidate); end
    candidate=candidate+o.arithmeticGuard*max(1,sum(abs(a.supportUpper))+abs(a.master.constant));
    state.active.node.upper=min(a.node.upper,candidate);
    node=state.active.node; if node.id==1, state.rootConfigurationUpper=min(state.rootConfigurationUpper,node.upper); end
    candidates=[a.master.rounded,{a.groups}];
    for j=1:numel(candidates), consider(candidates{j}); end
    added=0;
    for m=1:M, added=added+add_group(m,a.groups(:,m)); end
    pricedLP=all(a.complete) && strcmp(a.master.masterStatus,'optimal') && a.master.artificial<=o.lpTolerance && ...
        max(a.supportUpper-a.master.blockDual.')<=o.lpTolerance && ...
        abs(node.upper-a.master.masterValue)<=10*o.lpTolerance*max(1,abs(node.upper));
    if node.id==1 && pricedLP, state.rootLPComplete=true; end
    branchVariable=0; outcome='continue_pricing_tree';
    if node.upper<=state.lower
        state.closedUpper=max(state.closedUpper,node.upper); state.active=[]; outcome='bound_pruned';
    elseif added>0
        % New ORIGINAL columns change the LP prices; do not reuse old-price trees.
        state.queue{end+1}=node; state.active=[]; outcome='columns_added';
    elseif all(a.complete) || pricedLP
        free=node.fixed==-1; f=min(a.master.fractionalX,1-a.master.fractionalX); f(~free)=-Inf;
        [v,branchVariable]=max(f(:)); if v<1e-8, branchVariable=find(free,1); end
        for value=0:1
            child=node; child.fixed(branchVariable)=value; child.id=state.nextId;
            child.parent=node.id; child.depth=node.depth+1; child.visited=false;
            state.nextId=state.nextId+1; state.queue{end+1}=child;
        end
        state.active=[]; outcome='binary_schedule_branch';
    else
        % No improving column has yet been found: continue EXACTLY these fixed
        % price trees next sweep instead of claiming full pricing or LP optimality.
        state.active.nextBlock=1; state.active.passes=a.passes+1;
    end
    update_upper();
    row=struct('sweep',state.sweeps,'scheduleNode',node.id,'nodeUpper',node.upper, ...
        'globalLower',state.lower,'globalUpper',state.upper,'relativeGap',gap(), ...
        'restrictedMasterValue',a.master.masterValue,'masterStatus',a.master.masterStatus, ...
        'artificialDeficit',a.master.artificial,'rootLPComplete',state.rootLPComplete, ...
        'pricedBlocksComplete',nnz(a.complete),'newColumns',added,'openScheduleNodes',numel(state.queue), ...
        'branchVariable',branchVariable,'outcome',outcome,'elapsedSeconds',previousSeconds+toc(started));
    state.trace=leo_append_struct(state.trace,row);
    fprintf('Certificate %s: ORIGINAL optimum in [%.10g, %.10g], gap %.5g%%; %s.\n',phase,state.lower,state.upper,100*gap(),outcome);
    checkpoint();
end
update_upper();
if met(), state.status='gap_target_met';
elseif isempty(state.active) && isempty(state.queue), state.status='all_schedule_branches_closed';
elseif toc(started)>=o.maxSeconds, state.status='time_limit_unclosed'; end
checkpoint(); certificate=leo_v15_certificate_result(state,o);
save(fullfile(directory,'certificate.mat'),'certificate','-v7');
leo_v15_export_certificate(state,certificate,directory);
fprintf('Certificate %s FINAL: L=%.12g U=%.12g gap=%.6g%% target_met=%d; %s.\n', ...
    phase,state.lower,state.upper,100*gap(),certificate.gapTargetMet,state.status);
if ~certificate.gapTargetMet
    fprintf('认证精度尚未达到；当前 U 仍是有效上界。重跑本命令可继续未搜索分支，不代表已接近最优。\n');
end

    function s=initialize()
        if strcmp(phase,'fairness')
            baseline=leo_cardinality_fairness_bound(report,struct('maxSeconds',Inf,'maxIterations',150)); upper=baseline.upper;
            if isfield(report,'fairnessCertificate') && isequaln(report.fairnessCertificate.problemDataSnapshot,d)
                upper=min(upper,report.fairnessCertificate.upper);
            end
        else
            baseline=leo_v14_floor_bound(report,floorValue,150); upper=baseline.upperBits/1e6;
            if isfield(report,'conditionalBounds')
                for z=1:numel(report.conditionalBounds)
                    bnd=report.conditionalBounds(z);
                    if bnd.fairnessFloor==floorValue, upper=min(upper,bnd.conditionalUpperBits/1e6); end
                end
            end
        end
        fixed=-ones(K,M,'int8'); fixed(~d.available)=0;
        root=struct('id',1,'parent',0,'depth',0,'fixed',fixed,'upper',upper,'visited',false);
        pool=struct('groups',{cell(1,M)},'ratios',{cell(1,M)});
        for z=1:M, pool.groups{z}=false(K,0); pool.ratios{z}=zeros(K,0); end
        s=struct('schemaVersion',1,'problemData',d,'phase',phase,'floor',floorValue, ...
            'arithmeticGuard',o.arithmeticGuard,'pricingTolerance',o.pricingTolerance, ...
            'queue',{{root}},'active',[],'pool',pool,'lower',-Inf,'upper',upper, ...
            'baselineUpper',upper,'baseline',baseline,'closedUpper',-Inf,'nextId',2, ...
            'incumbentX',[],'incumbentService',[],'nodesProcessed',0,'pricingNodes',0, ...
            'initialLower',-Inf, ...
            'sweeps',0,'blockCalls',0,'elapsedSeconds',0,'rootConfigurationUpper',upper, ...
            'rootLPComplete',false,'trace',struct([]),'pricingTrace',struct([]),'status','initialized');
    end
    function yes=legal(x)
        yes=isequal(size(x),[K,M]) && all(x(:)==0 | x(:)==1) && ...
            all(x(:)<=d.hard.upper) && all(d.hard.A*double(x(:))<=d.hard.rhs);
    end
    function value=objective(service)
        if strcmp(phase,'fairness'), value=service.fairness;
        elseif all(service.demandRatio>=floorValue), value=service.totalBits/1e6;
        else, value=-Inf; end
    end
    function consider(x)
        assert(legal(x),'Certificate candidate is not a feasible binary original schedule.');
        service=leo_evaluate_service(d,x); value=objective(service);
        if value>state.lower, state.lower=value; state.incumbentX=x; state.incumbentService=service; end
    end
    function add_schedule(x)
        for z=1:M, add_group(z,logical(x(:,z))); end
    end
    function n=add_group(m,g)
        n=0;
        if any(all(bsxfun(@eq,state.pool.groups{m},g),1)), return; end
        state.pool.groups{m}(:,end+1)=g;
        state.pool.ratios{m}(:,end+1)=leo_resource_service(d,m,g)./d.qosTargetBits; n=1;
    end
    function update_upper()
        values=[state.closedUpper,cellfun(@(x)x.upper,state.queue)];
        if ~isempty(state.active), values(end+1)=state.active.node.upper; end
        value=max(values);
        if isempty(value) || value==-Inf, value=state.lower; end
        if isfinite(state.lower) && value<state.lower-1e-7*max(1,abs(state.lower))
            error('leo:v15InvalidUpper','Original feasible value %.15g exceeds certified upper %.15g.',state.lower,value);
        end
        state.upper=max(state.lower,min(state.upper,value));
    end
    function value=gap()
        value=NaN; if isfinite(state.lower), value=max(0,state.upper-state.lower)/max(state.upper,eps); end
    end
    function yes=met()
        yes=isfinite(state.lower) && state.upper-state.lower<=max(o.absoluteGap,o.relativeGap*max(state.upper,eps));
    end
    function checkpoint()
        update_upper(); state.elapsedSeconds=previousSeconds+toc(started);
        temporary=[tempname(directory),'.mat']; save(temporary,'state','-v7');
        [ok,message]=movefile(temporary,path,'f'); assert(ok,message);
        progress=struct('phase',phase,'floor',floorValue,'lower',state.lower,'upper',state.upper, ...
            'relativeGap',gap(),'status',state.status,'sweeps',state.sweeps, ...
            'pricingCalls',state.blockCalls,'pricingNodes',state.pricingNodes,'elapsedSeconds',state.elapsedSeconds);
        leo_write_struct_csv(fullfile(directory,'progress.csv'),progress);
    end
end
