function [audit,files] = run_leo_v13_candidate_audit(source,overrides,render)
%RUN_LEO_V13_CANDIDATE_AUDIT 原式Tabu改进动作与实际代理/价格的事后对照。
% 实际在线快照保留原代理切点、价格及内层提案；旧数据缺失时明确标为重建。
% 所有探测均在计时搜索完成之后，不把诊断动作送回任何被测方法。
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
files={};
report=leo_v12_load_report(source); data=report.problemData;
directory=fullfile('results','v13_candidate_audit');
if ischar(source), directory=fullfile(source,'candidate_audit'); end
o=struct('maxSeconds',60,'maxReferencesPerPhase',3,'maxNeighbors',320, ...
    'maxCandidates',8,'maxTabuMovesPerPhase',8,'outputDirectory',directory);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
assert(o.maxSeconds>0 && all([o.maxReferencesPerPhase,o.maxNeighbors,o.maxCandidates,o.maxTabuMovesPerPhase]>=1));
directory=o.outputDirectory; if ~exist(directory,'dir'), mkdir(directory); end
sourceSignature=signature(report); savedPath=fullfile(directory,'candidate_audit.mat');
if exist(savedPath,'file')==2
    saved=load(savedPath,'audit');
    if strcmp(saved.audit.version,'V13 original candidate diagnosis 2') && isfield(saved.audit,'sourceSignature') && isequaln(saved.audit.sourceSignature,sourceSignature) && isequaln(saved.audit.options,o)
        audit=saved.audit; fprintf('Candidate audit retained; same frozen search evidence and diagnostic settings.\n');
        if render, files=leo_render_plot_specs(make_specs(audit),directory); end
        return;
    end
end
budget=struct('timer',tic,'seconds',o.maxSeconds); rows=struct([]); references=struct([]); witnesses={};
problem=struct('data',data,'evaluate',@(x) leo_evaluate_service(data,x));
ids=cellfun(@leo_method_id,{report.records.method},'UniformOutput',false);
for j=1:numel(report.records)
    if ~any(strcmp(ids{j},{'sb_v12_lexicographic','local_v12_lexicographic'})) || ~strcmp(report.records(j).status,'completed'), continue; end
    r=report.records(j); sol=report.solutions{j};
    for phaseIndex=1:2
        stage=sol.(sprintf('stage%d',phaseIndex)); snapshots={};
        if isfield(stage,'auditSnapshots'), snapshots=stage.auditSnapshots; end
        if isempty(snapshots) && isfield(stage,'proxy') && ~isempty(stage.proxy)
            lambda=ones(data.shape(1),1)/data.shape(1); phase='fairness'; floorValue=0;
            if phaseIndex==2, lambda(:)=0; phase='throughput'; floorValue=sol.fairnessFloor; end
            if ~isempty(stage.history.lambda), lambda=stage.history.lambda(:,end); end
            snapshots={struct('iteration',NaN,'phase',phase,'floor',floorValue,'x',stage.x, ...
                'lambda',lambda,'referenceW',stage.proxy.referenceW,'solved',false(1,data.shape(2)))};
        end
        select=unique(round(linspace(1,numel(snapshots),min(numel(snapshots),o.maxReferencesPerPhase))));
        for si=select
            if leo_budget_expired(budget), break; end
            snap=snapshots{si}; original=problem.evaluate(snap.x);
            lower=from_reference(snap.referenceW); [weights,~]=leo_price_weights(data,snap.lambda,snap.phase,snap.floor);
            provenance='online_frozen_proxy_and_prices';
            if ~isfield(snap,'proposed'), provenance='posthoc_final_proxy_last_prices_no_inner_witness'; end
            pool=leo_original_neighbors(problem,snap.x,original,o.maxNeighbors,max(1,si),budget);
            good=[];
            for k=1:numel(pool)
                if leo_service_is_better(pool(k).service,original,snap.phase,snap.floor), good(end+1)=k; end %#ok<AGROW>
            end
            entry=struct('method',leo_method_name(r.method),'seed',r.seed,'phase',phaseIndex, ...
                'snapshot',si,'iteration',snap.iteration,'provenance',provenance, ...
                'neighborsScored',numel(pool),'originalImprovingNeighbors',numel(good));
            references=leo_append_struct(references,entry);
            for rank=1:min(numel(good),o.maxCandidates)
                best=1;
                for k=2:numel(good)
                    if leo_service_is_better(pool(good(k)).service,pool(good(best)).service,snap.phase,snap.floor), best=k; end
                end
                index=good(best); good(best)=[];
                inspect(snap.x,pool(index).x,lower,weights,snap,r,phaseIndex,si, ...
                    'Tabu_neighborhood_probe',provenance,original);
            end
        end
    end
end
% 同时检验真正记录到的Tabu接受改进动作；它自身没有代理或价格，借用SB末价格须注明。
touchingTemplate=[];
for j=1:numel(report.records)
    r=report.records(j);
    if ~strcmp(ids{j},'original_tabu') || ~strcmp(r.status,'completed'), continue; end
    sb=find(strcmp(ids,'sb_v12_lexicographic') & [report.records.seed]==r.seed & strcmp({report.records.status},'completed'),1);
    if isempty(sb), continue; end
    for phaseIndex=1:2
        stage=report.solutions{j}.(sprintf('stage%d',phaseIndex));
        if ~isfield(stage,'auditMoves'), continue; end
        moves=stage.auditMoves; h=report.solutions{sb}.(sprintf('stage%d',phaseIndex)).history;
        for mi=unique(round(linspace(1,numel(moves),min(numel(moves),o.maxTabuMovesPerPhase))))
            if leo_budget_expired(budget), break; end
            move=moves{mi}; lambda=ones(data.shape(1),1)/data.shape(1);
            if phaseIndex==2, lambda(:)=0; end
            if ~isempty(h.lambda), lambda=h.lambda(:,end); end
            [weights,~]=leo_price_weights(data,lambda,move.phase,move.floor);
            if isempty(touchingTemplate)
                touchingTemplate=leo_v12_build_service_surrogates(problem,'current_schedule',move.xBefore);
            end
            W=touchingTemplate.minimaxReferenceW; actual=leo_schedule_interference(data,move.xBefore);
            for t=1:numel(data.slotToResource)
                selected=move.xBefore(:,data.slotToResource(t)) & touchingTemplate.limits.eventMask(:,t);
                W(selected,t)=actual(selected,t);
            end
            touchingLower=from_reference(W);
            snap=struct('phase',move.phase,'floor',move.floor,'solved',false(1,data.shape(2)));
            inspect(move.xBefore,move.xAfter,touchingLower,weights,snap,r,phaseIndex,mi, ...
                'recorded_Tabu_move','fresh_touching_proxy_SB_last_prices_counterfactual');
        end
    end
end
audit=struct('version','V13 original candidate diagnosis 2','options',o,'rows',rows, ...
    'sourceSignature',sourceSignature, ...
    'references',references,'witnesses',{witnesses},'problemDataSnapshot',data, ...
    'timeLimited',leo_budget_expired(budget),'elapsedSeconds',toc(budget.timer), ...
    'scope','Sampled original-model improving actions. Weight misalignment, proxy reversal and known inner-score shortfall are different evidence. Missing online snapshots cannot prove an inner-search miss.');
leo_write_struct_csv(fullfile(directory,'candidate_scores.csv'),rows);
leo_write_struct_csv(fullfile(directory,'references.csv'),references);
save(fullfile(directory,'candidate_audit.mat'),'audit','-v7');
specs=make_specs(audit); fid=fopen(fullfile(directory,'candidate_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
if render, files=leo_render_plot_specs(specs,directory); end
if isempty(rows)
    fprintf('Candidate audit: no improving candidate found in the sampled neighborhoods; this is not a global optimality certificate.\n');
else
    fprintf('Candidate audit: %d original improving actions; weight misalignment %d, proxy reversals %d, witnessed inner shortfalls %d; time-limited=%d.\n', ...
        numel(rows),sum([rows.weightMisaligned]),sum([rows.proxyReversed]),sum([rows.innerMiss]==1),audit.timeLimited);
end
    function lower=from_reference(W)
        line=leo_tangent_lower(data.design.signalW,data.design.noiseW,data.bandwidthHz,W);
        for t=1:numel(data.slotToResource)
            mask=data.available(:,data.slotToResource(t)) & data.dataDurationS(t)>0;
            line.alphaBps(~mask,t)=0; line.omegaBpsPerW(~mask,t)=0;
        end
        lower=leo_assemble_quadratic_service(data,line.alphaBps,line.omegaBpsPerW);
    end
    function bits=proxy_bits(lower,x)
        x=double(x); bits=sum(lower.aBits.*x,2);
        for mm=1:data.shape(2), bits=bits-x(:,mm).*(lower.bBits(:,:,mm)*x(:,mm)); end
    end
    function inspect(beforeX,afterX,lower,w,snap,r,phaseIndex,ref,origin,provenance,before)
        if nargin<11, before=problem.evaluate(beforeX); end
        after=problem.evaluate(afterX);
        if ~leo_service_is_better(after,before,snap.phase,snap.floor), return; end
        originalGain=w.'*(after.effectiveUserBits-before.effectiveUserBits);
        proxyGain=w.'*(proxy_bits(lower,afterX)-proxy_bits(lower,beforeX));
        tolerance=1e-10*max([1,abs(w.'*before.effectiveUserBits),abs(w.'*after.effectiveUserBits)]);
        changed=find(any(beforeX~=afterX,1)); shortfall=NaN; missed=NaN;
        if isfield(snap,'proposed')
            delta=[];
            for mm=changed
                if ~snap.solved(mm), continue; end
                score=@(g) w.'*(lower.aBits(:,mm).*double(g)-double(g).*(lower.bBits(:,:,mm)*double(g)));
                delta(end+1)=score(afterX(:,mm))-score(snap.proposed(:,mm)); %#ok<AGROW>
            end
            if ~isempty(delta), shortfall=max(delta); end
            if any(delta>tolerance), missed=1;
            elseif all(snap.solved(changed)), missed=0; end
        end
        misaligned=originalGain<=tolerance; reversed=originalGain>tolerance && proxyGain<=tolerance;
        diagnosis='outer_selection_or_coordination';
        if misaligned, diagnosis='price_weight_misalignment';
        elseif reversed, diagnosis='proxy_ranking_reversal';
        elseif missed==1, diagnosis='witnessed_inner_search_miss';
        elseif isnan(missed), diagnosis='positive_proxy_gain_inner_unknown'; end
        row=struct('method',leo_method_name(r.method),'seed',r.seed,'phase',phaseIndex,'reference',ref, ...
            'origin',origin,'provenance',provenance,'changedResources',numel(changed), ...
            'fairnessBefore',before.fairness,'fairnessAfter',after.fairness, ...
            'deltaFairness',after.fairness-before.fairness,'deltaTotalBits',after.totalBits-before.totalBits, ...
            'originalWeightedGain',originalGain,'proxyWeightedGain',proxyGain, ...
            'weightMisaligned',misaligned,'proxyReversed',reversed,'innerMiss',missed, ...
            'innerScoreShortfall',shortfall,'diagnosis',diagnosis);
        rows=leo_append_struct(rows,row);
        witnesses{end+1}=struct('xBefore',beforeX,'xAfter',afterX,'weights',w,'lower',lower); %#ok<AGROW>
    end
end
function key=signature(report)
evidence=cell(size(report.solutions));
for j=1:numel(report.solutions)
    r=report.records(j); s=report.solutions{j};
    item=struct('method',r.method,'seed',r.seed,'status',r.status);
    if strcmp(r.status,'completed')
        for phase=1:2
            st=s.(sprintf('stage%d',phase)); a=struct();
            for name={'x','history','proxy','auditSnapshots','auditMoves'}
                if ~isfield(st,name{1}), continue; end
                if strcmp(name{1},'history')
                    a.lambda=[]; if isfield(st.history,'lambda'), a.lambda=st.history.lambda; end
                elseif strcmp(name{1},'proxy')
                    a.referenceW=[]; if ~isempty(st.proxy), a.referenceW=st.proxy.referenceW; end
                else, a.(name{1})=st.(name{1}); end
            end
            item.(sprintf('stage%d',phase))=a;
        end
    end
    evidence{j}=item;
end
key=struct('problemData',report.problemData,'evidence',{evidence});
end
function spec=make_specs(audit)
p=panel('Sampled original improving actions: diagnosed obstacle','Diagnosis','Count');
p.kind='categorical_line'; p.labels={'Price weights','Proxy reversal','Inner miss','Other/unknown'};
r=audit.rows; counts=zeros(1,4);
if ~isempty(r)
    counts=[sum([r.weightMisaligned]),sum([r.proxyReversed]), ...
        sum(strcmp({r.diagnosis},'witnessed_inner_search_miss')),sum(ismember({r.diagnosis},{'outer_selection_or_coordination','positive_proxy_gain_inner_unknown'}))];
end
p=add(p,'Improving actions',1:4,counts);
p(2)=panel('Original weighted gain versus quadratic proxy gain','Original weighted gain','Proxy weighted gain'); p(2).kind='scatter';
p(3)=panel('Original fairness gains of sampled candidates','Candidate index','Delta min G/q');
p(4)=panel('Known candidate score minus recorded inner score','Candidate index','Proxy score shortfall');
if ~isempty(r)
    for method=unique({r.method},'stable')
        at=find(strcmp({r.method},method{1})); a=r(at);
        p(2)=add(p(2),method{1},[a.originalWeightedGain],[a.proxyWeightedGain]);
        p(3)=add(p(3),method{1},at,[a.deltaFairness]);
        p(4)=add(p(4),method{1},at,[a.innerScoreShortfall]);
    end
end
for j=1:4, p(j).note=audit.scope; end
spec=struct('name','v13_candidate_diagnosis','title','Original Tabu actions and frozen proxy diagnosis | post-search only','rows',2,'cols',2,'panels',p);
end
function p=panel(titleText,x,y)
p=struct('kind','line','title',titleText,'xlabel',x,'ylabel',y,'labels',{{}},'series',struct([]), ...
    'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}},'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=add(p,name,x,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]));
end
