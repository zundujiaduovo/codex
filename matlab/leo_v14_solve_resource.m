function out=leo_v14_solve_resource(data,lower,m,w,oldGroup,o,budget,context)
% 相同约束/代理/候选决策下的SB、Local、Tabu；记录三个处理阶段。
q=leo_build_resource_qubo(data,lower,m,w,o); q=leo_v14_encode_qubo(q,o.penaltyFactor);
old=logical(oldGroup(q.userIds)); groups=old; sources={'warm_start'}; repairs=0;
sbSteps=0; trajectorySteps=0; denseTerms=0; restartCount=0; tabuIterations=0; tabuCandidates=0;
rawScores=[]; fixedScores=[]; polishedScores=[]; rawLegal=[]; rawEnergy=[]; encodedLegal=[];
switch o.innerSolver
 case 'sb'
    seeds=[leo_encode_group_bits(q,old),leo_encode_group_bits(q,false(q.nUsers,1))];
    if isfield(o,'parallel') && o.parallel.enabled
        sb=leo_v16_parallel_sb(q,o,seeds,o.coordination.sbKernel);
        trajectorySteps=sb.trajectorySteps; denseTerms=sb.denseTerms; restartCount=sb.restarts;
    elseif strcmp(o.coordination.sbKernel,'adaptive')
        sb=leo_v14_adaptive_sb(q,o,seeds,budget); trajectorySteps=sb.trajectorySteps;
        denseTerms=sb.denseTerms; restartCount=sb.restarts;
    else
        sb=leo_v8_ballistic_sb(leo_qubo_to_ising(q),o,seeds,budget);
        trajectorySteps=sb.steps*o.sbTrajectories; denseTerms=q.nBits^2*trajectorySteps;
    end
    sbSteps=sb.steps;
    for j=1:size(sb.bits,2)
        raw=logical(sb.bits(1:q.nUsers,j)); add(raw,'sb');
        rawEnergy(end+1)=q.constant+sb.bits(:,j).'*q.Qsym*sb.bits(:,j); %#ok<AGROW>
        valid=rawLegal(end);
        if q.capacityIncluded, valid=valid && sum(raw)+q.slackWeights.'*sb.bits(q.nUsers+1:end,j)==q.maxStreams; end
        encodedLegal(end+1)=valid; %#ok<AGROW>
    end
    if isfield(sb,'legalGroups')
        for j=1:size(sb.legalGroups,2), add(sb.legalGroups(:,j),'sb_legal_checkpoint',false); end
    end
 case 'local'
    for j=1:o.localRestarts
        if leo_budget_expired(budget), break; end
        if j==1, x=old; elseif j==2, x=false(q.nUsers,1); else, x=rand(q.nUsers,1)<.5; end
        add(x,'local');
    end
 case 'tabu'
    search=leo_proxy_tabu_group(q,old,o,budget); tabuIterations=search.iterations; tabuCandidates=search.candidates;
    add(search.x,'tabu');
    if isfield(search,'candidateGroups')
        for j=1:size(search.candidateGroups,2), retain(search.candidateGroups(:,j),'tabu_trajectory'); end
    end
 otherwise, error('leo:v14Solver','V14 supports sb/local/tabu.');
end
pathCount=0; bridgeCount=0;
throughput=isfield(context,'phase') && strcmp(context.phase,'throughput');
if throughput && o.coordination.stage2TrustPaths
    center=logical(context.group(q.userIds));
    [~,path]=leo_v14_trust_path(q,center,[],context.radius,o.polishMoves);
    for j=2:size(path,2), retain(path(:,j),'trust_ascent_step'); pathCount=pathCount+1; end
    % 远提案不能只删除：挑不同方向，在边界以内保留每个中间组。
    distance=sum(bsxfun(@ne,groups,center),1); far=find(distance>context.radius);
    if ~isempty(far)
        raw=double(groups(:,far)); values=q.A.'*raw-sum(raw.*(q.B*raw),1)/2;
        [~,order]=sort(values,'descend'); tried=false(q.nUsers,0); count=0;
        for j=order
            target=groups(:,far(j));
            if any(all(bsxfun(@eq,tried,target),1)), continue; end
            tried(:,end+1)=target; count=count+1;
            [~,path]=leo_v14_trust_path(q,center,target,context.radius,o.polishMoves);
            for k=2:size(path,2), retain(path(:,k),'trust_bridge_step'); bridgeCount=bridgeCount+1; end
            if count>=o.coordination.stage2BridgeTargets, break; end
        end
    end
end
feasibleGroups=false(data.shape(1),size(groups,2)); feasibleGroups(q.userIds,:)=groups;
feasibleGroups=[context.group,feasibleGroups]; sources=[{'incumbent'},sources];
distance=sum(bsxfun(@ne,feasibleGroups,context.group),1); allowed=distance<=context.radius;
rejected=nnz(~allowed);
feasibleGroups=feasibleGroups(:,allowed); sources=sources(allowed);
if isempty(feasibleGroups), feasibleGroups=context.group; sources={'incumbent'}; end
pool=leo_v14_select_candidates(data,m,q,feasibleGroups,sources,context,o.refinement.poolSize);
z=double(feasibleGroups(q.userIds,:)); values=q.A.'*z-sum(z.*(q.B*z),1)/2;
[bestScore,at]=max(values); best=feasibleGroups(:,at);
if ~any(all_columns(pool.groups,best))
    pool.groups(:,end)=best; pool.sources{end}='proxy_best';
end
out=struct('x',best,'bits',leo_encode_group_bits(q,best(q.userIds)),'score',bestScore, ...
 'oldScore',proxy(old),'sbSteps',sbSteps,'nRepaired',repairs,'nBits',q.nBits,'optimal',false, ...
 'candidateGroups',pool.groups,'candidateSources',{pool.sources},'candidateClasses',{pool.sources}, ...
 'novelCandidates',nnz(any(bsxfun(@ne,pool.groups,context.group),1)), ...
 'trustPathCandidates',pathCount,'trustBridgeCandidates',bridgeCount,'trustRejectedCandidates',rejected, ...
 'preselectionEvaluations',pool.preselectionEvaluations, ...
 'trajectorySteps',trajectorySteps,'denseTerms',denseTerms,'restarts',restartCount, ...
 'tabuIterations',tabuIterations,'tabuCandidates',tabuCandidates, ...
 'rawScore',best_or_nan(rawScores),'repairedScore',best_or_nan(fixedScores),'polishedScore',best_or_nan(polishedScores), ...
 'rawLegalFraction',mean_or_nan(rawLegal),'rawEncodedLegalFraction',mean_or_nan(encodedLegal),'rawEnergy',-best_or_nan(-rawEnergy));
out.repairLoss=mean_or_nan(max(0,rawScores-fixedScores));
out.polishGain=mean_or_nan(polishedScores-fixedScores); out.nextPenalty=o.penaltyFactor;
if o.coordination.adaptivePenalty && strcmp(o.innerSolver,'sb') && ~isempty(rawScores)
    denominator=max(1,max(abs(rawScores)));
    if out.rawEncodedLegalFraction<.25 || out.repairLoss/denominator>o.coordination.repairLossTrigger
        out.nextPenalty=min(o.coordination.penaltyMax,o.penaltyFactor*1.5);
    elseif out.rawEncodedLegalFraction>.9 && out.repairLoss<=1e-10
        out.nextPenalty=max(1.1001,o.penaltyFactor/1.1);
    end
end
if strcmp(o.innerSolver,'sb')
    out.energyHistory=sb.history; out.energyScale=sb.energyScale; out.trajectories=sb.trajectories;
end
out.parallelWorkers=0; out.parallelTasks=0;
if strcmp(o.innerSolver,'sb') && isfield(sb,'parallelWorkers')
    out.parallelWorkers=sb.parallelWorkers; out.parallelTasks=sb.parallelTasks;
end
    function add(raw,source,diagnose)
        if nargin<3, diagnose=true; end
        fixed=leo_repair_group(q,raw); repairs=repairs+any(raw~=fixed);
        polished=leo_polish_group(q,fixed,o.polishMoves);
        if diagnose
            ids=find(raw); rawLegal(end+1)=numel(ids)<=q.maxStreams && numel(unique(q.beamIndex(ids)))==numel(ids);
            rawScores(end+1)=proxy(raw); fixedScores(end+1)=proxy(fixed); polishedScores(end+1)=proxy(polished);
        end
        retain(fixed,[source,'_repaired']); retain(polished,[source,'_polished']);
    end
    function retain(x,source)
        groups(:,end+1)=x; sources{end+1}=source;
    end
    function value=proxy(x)
        z=double(x); value=q.A.'*z-z.'*q.B*z/2;
    end
end
function yes=all_columns(groups,g)
yes=all(bsxfun(@eq,groups,g),1);
end
function x=best_or_nan(v)
x=NaN; if ~isempty(v), x=max(v); end
end
function x=mean_or_nan(v)
x=NaN; if ~isempty(v), x=mean(v); end
end
