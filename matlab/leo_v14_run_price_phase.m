function result=leo_v14_run_price_phase(problem,proxy,cache,phase,start,o,budget)
% 归一化公平协调、增益可信域、收益调度、瓶颈跨块补偿的公共外层。
d=problem.data; K=d.shape(1); M=d.shape(2);
c=leo_v14_coordination_options(o.coordination); o.coordination=c; isFair=strcmp(phase,'fairness');
conv=leo_v16_convergence_options(); if isfield(o,'convergence'), conv=leo_v16_convergence_options(o.convergence); end
unlimited=conv.enabled; convergence=[];
bestX=start.x; service=start.service; priceX=bestX; s0=0;
lambda=ones(K,1)/K; rounds=o.fairnessRounds; initialStep=o.fairnessStep;
if ~isFair, s0=service.fairness; lambda=zeros(K,1); rounds=o.throughputRounds; initialStep=o.throughputStep; end
if ~isFair && isfinite(c.stage2Floor), s0=c.stage2Floor; assert(all(service.demandRatio>=s0)); end
upper=leo_original_upper_bound(d,cache,lambda,phase,s0); initialUpper=upper.value; initialSeconds=toc(budget.timer);
radius=c.trustInitial*ones(1,M); penalty=o.penaltyFactor*ones(1,M);
fail=zeros(M,2); next=zeros(M,2); priceState=struct(); evidence=struct([]); snapshots={}; firstTrace=[];
stagnantRounds=0;
checkpoints=point([],service,0,'initial'); epoch=1; errors=proxy.error.optimalFairnessGapBound; touch=proxy.referenceTouchMaxAbsBits;
names={'sAux','step','priceFairness','priceTotalBits','savedFairness','savedTotalBits','upperBound','proxyEpoch', ...
 'innerImprovement','resourcesSolved','sbSteps','repairedCandidates','recoveryEvaluations','crossEvaluations','acceptedMoves', ...
 'elapsedSeconds','blockwiseEvaluations','blockwiseAccepted','innerSeconds','innerTabuIterations','innerTabuCandidates', ...
 'originalSelectionSeconds','recoverySeconds','proxyRefreshSeconds','maxQuboBits','sbTrajectorySteps','denseDynamicsTerms', ...
 'extraInnerCalls','candidateGapEvaluations','candidateCutRefreshes','candidateCutSeconds','maxCandidateGapBefore','maxCandidateGapAfter', ...
 'poolAccepted','bottleneckAccepted','retangentAccepted','priceScheduleAccepted','recoveryAccepted','lambdaSum', ...
 'jointEvaluations','jointAccepted','jointFairnessGain','gainPredictionErrors','rankingReversals','trustRadius', ...
 'skippedExtraCalls','sbRestarts','repairLoss','rawScore','repairedScore','polishedScore', ...
 'novelCandidates','trustPathCandidates','trustBridgeCandidates','trustRejectedCandidates','trustEscape','stage2StagnantRounds', ...
 'parallelWorkers','parallelTasks','stableWindows','lastWindowGain'};
capacity=rounds; if unlimited, capacity=128; end
for j=1:numel(names), history.(names{j})=zeros(1,capacity); end
history.lambda=zeros(K,capacity); history.lambdaNext=zeros(K,capacity); history.lowerUserBits=zeros(K,capacity);
history.priceX=false(K,M,capacity); history.completePriceRound=false(1,capacity);
[stopping,~]=leo_search_stopping(o,phase,service,upper.value,initialSeconds,0); completed=0; status='iteration_limit';
[convergence,~]=leo_v16_convergence_step(o,phase,service,0,convergence);
k=0;
while unlimited || k<rounds
    k=k+1;
    if k>capacity
        capacity=capacity+128;
        for name=fieldnames(history).'
            if strcmp(name{1},'priceX'), history.(name{1})(:,:,capacity)=false;
            else, history.(name{1})(:,capacity)=0; end
        end
    end
    if leo_budget_expired(budget), status='time_limit'; break; end
    roundStartTotal=service.totalBits;
    if ~isFair && c.stage2StallExpand && stagnantRounds>=c.stage2StallRounds && mod(k,c.stage2EscapeEvery)==0
        radius=min(c.trustMax,max(radius+2,ceil(1.5*radius))); history.trustEscape(k)=1;
    end
    [w,sAux]=leo_price_weights(d,lambda,phase,s0,o); banks=cell(1,M);
    history.lambda(:,k)=lambda; history.sAux(k)=sAux; history.lambdaSum(k)=sum(lambda);
    snap=struct('iteration',k,'phase',phase,'floor',s0,'x',bestX,'priceStart',priceX, ...
        'lambda',lambda,'referenceW',proxy.referenceW,'seconds',toc(budget.timer),'solved',false(1,M));
    order=mod((0:M-1)+k-1,M)+1;
    for m=order
        if leo_budget_expired(budget), break; end
        ctx=struct('group',bestX(:,m),'service',service,'radius',radius(m),'phase',phase); local=o; local.penaltyFactor=penalty(m);
        started=tic; inner=leo_v14_solve_resource(d,proxy.lower,m,w,priceX(:,m),local,budget,ctx); seconds=toc(started);
        main=inner; addwork(inner,seconds); record('main',inner,seconds,NaN,NaN);
        penalty(m)=inner.nextPenalty;
        if isempty(firstTrace) && isfield(inner,'energyHistory')
            firstTrace=struct('history',inner.energyHistory,'resource',m,'priceIteration',k,'trajectories',o.sbTrajectories,'energyScale',inner.energyScale);
        end
        a=double(inner.x); b=double(ctx.group);
        actual=w.'*(leo_resource_service(d,m,inner.x)-service.resourceBits(:,m));
        estimate=w.'*(polynomial(proxy.lower,a)-polynomial(proxy.lower,b));
        history.candidateGapEvaluations(k)=history.candidateGapEvaluations(k)+1;
        error=abs(actual-estimate)/max([c.gainAbsoluteTolerance,abs(actual),abs(estimate)]);
        reversed=actual*estimate<0 && max(abs([actual,estimate]))>c.gainAbsoluteTolerance;
        unreliable=reversed || error>c.gainRelativeTolerance;
        if any(a~=b)
            if unreliable, radius(m)=max(c.trustMin,floor(radius(m)/2));
            else, radius(m)=min(c.trustMax,max(radius(m)+1,ceil(1.5*radius(m)))); end
        end
        history.gainPredictionErrors(k)=history.gainPredictionErrors(k)+error;
        history.rankingReversals(k)=history.rankingReversals(k)+reversed;
        evidence(end).originalWeightedGain=actual; evidence(end).proxyWeightedGain=estimate;
        called=false(1,2);
        for family=1:2
            requested=(family==1 && unreliable && o.refinement.candidateRefresh) || ...
                (family==2 && o.refinement.bottleneckCandidates);
            allowed=k>=next(m,family) || mod(k,c.familyProbeEvery)==0;
            if ~requested, continue; end
            if ~allowed, history.skippedExtraCalls(k)=history.skippedExtraCalls(k)+1; continue; end
            ctx.radius=radius(m); lower=proxy.lower; weights=w; source='extra_bottleneck';
            cutSeconds=0;
            if family==1
                source='extra_retangent'; started=tic; lower=leo_v13_touch_resource(d,proxy,m,inner.x); cutSeconds=toc(started);
                history.candidateCutRefreshes(k)=history.candidateCutRefreshes(k)+1;
                history.candidateCutSeconds(k)=history.candidateCutSeconds(k)+cutSeconds;
            else
                distance=service.demandRatio-min(service.demandRatio);
                if ~isFair, distance=max(0,service.demandRatio-s0); end
                priority=exp(-min(distance/o.refinement.bottleneckBand,700)); priority=priority/sum(priority);
                weights=priority./d.qosTargetBits; if ~isFair, weights=weights+1/d.referenceBits; end
            end
            started=tic; extra=leo_v14_solve_resource(d,lower,m,weights,bestX(:,m),local,budget,ctx); seconds=toc(started)+cutSeconds;
            addwork(extra,seconds); called(family)=true;
            ge=double(extra.x);
            gainExact=weights.'*(leo_resource_service(d,m,extra.x)-service.resourceBits(:,m));
            gainProxy=weights.'*(polynomial(lower,ge)-polynomial(lower,double(ctx.group)));
            history.candidateGapEvaluations(k)=history.candidateGapEvaluations(k)+1;
            record(source,extra,seconds,gainExact,gainProxy);
            history.extraInnerCalls(k)=history.extraInnerCalls(k)+1;
            inner.candidateGroups=[inner.candidateGroups,extra.candidateGroups];
            inner.candidateSources=[inner.candidateSources,repmat({source},1,size(extra.candidateGroups,2))];
            inner.candidateClasses=[inner.candidateClasses,extra.candidateClasses];
        end
        banks{m}=struct('groups',inner.candidateGroups,'sources',{inner.candidateSources});
        before=service; started=tic;
        accepted=leo_accept_resource_candidates(problem,bestX,service,m,inner,phase,s0,budget);
        history.originalSelectionSeconds(k)=history.originalSelectionSeconds(k)+toc(started);
        history.blockwiseEvaluations(k)=history.blockwiseEvaluations(k)+accepted.evaluations;
        if accepted.accepted
            bestX=accepted.x; service=accepted.service; checkpoints=point(checkpoints,service,k,['block:',accepted.source]);
            history.blockwiseAccepted(k)=history.blockwiseAccepted(k)+1;
            history.poolAccepted(k)=history.poolAccepted(k)+accepted.nonProxyWinner;
            history.bottleneckAccepted(k)=history.bottleneckAccepted(k)+strcmp(accepted.source,'extra_bottleneck');
            history.retangentAccepted(k)=history.retangentAccepted(k)+strcmp(accepted.source,'extra_retangent');
            for e=numel(evidence):-1:1
                if evidence(e).round~=k || evidence(e).resource~=m, break; end
                if strcmp(evidence(e).family,accepted.source) || (strcmp(evidence(e).family,'main') && isempty(strfind(accepted.source,'extra_')))
                    evidence(e).acceptedFairnessGain=service.fairness-before.fairness;
                    evidence(e).acceptedTotalGainBits=service.totalBits-before.totalBits;
                    evidence(e).candidateFamilies=accepted.candidateClass; break;
                end
            end
        end
        for family=1:2
            if ~called(family), continue; end
            label='extra_retangent'; if family==2, label='extra_bottleneck'; end
            reward=service.fairness-before.fairness>c.gainAbsoluteTolerance;
            if ~isFair, reward=service.totalBits-before.totalBits>c.gainAbsoluteTolerance*max(1,before.totalBits); end
            if accepted.accepted && strcmp(accepted.source,label) && reward, fail(m,family)=0; next(m,family)=k+1;
            else
                fail(m,family)=fail(m,family)+1;
                if fail(m,family)>=c.familyPatience, next(m,family)=k+c.familyCooldown; end
            end
        end
        priceX(:,m)=main.x; snap.solved(m)=true;
        history.innerImprovement(k)=history.innerImprovement(k)+main.score-main.oldScore;
        history.resourcesSolved(k)=history.resourcesSolved(k)+1;
    end
    before=service; started=tic;
    joint=leo_v14_joint_blocks(problem,struct('x',bestX,'service',service),banks,phase,s0,o,budget);
    jointSeconds=toc(started); history.originalSelectionSeconds(k)=history.originalSelectionSeconds(k)+jointSeconds;
    history.blockwiseEvaluations(k)=history.blockwiseEvaluations(k)+joint.resourceEvaluations;
    history.jointEvaluations(k)=joint.evaluations; history.jointAccepted(k)=joint.accepted;
    if joint.accepted
        bestX=joint.x; service=joint.service; checkpoints=point(checkpoints,service,k,'joint_blocks');
        history.jointFairnessGain(k)=service.fairness-before.fairness;
        for j=1:numel(joint.blocks)
            family=0; if strcmp(joint.sources{j},'extra_retangent'), family=1; end
            if strcmp(joint.sources{j},'extra_bottleneck'), family=2; end
            reward=service.fairness-before.fairness>c.gainAbsoluteTolerance;
            if ~isFair, reward=service.totalBits-before.totalBits>c.gainAbsoluteTolerance*max(1,before.totalBits); end
            if family>0 && reward, fail(joint.blocks(j),family)=0; next(joint.blocks(j),family)=k+1; end
        end
        row=evidence(end); row.family='joint'; row.resource=0; row.seconds=jointSeconds;
        row.rawScore=NaN; row.repairedScore=NaN; row.polishedScore=NaN; row.repairLoss=NaN; row.polishGain=NaN;
        row.rawLegalFraction=NaN; row.rawEncodedLegalFraction=NaN; row.rawEnergy=NaN;
        row.penaltyFactor=NaN;
        row.originalWeightedGain=NaN; row.proxyWeightedGain=NaN;
        row.acceptedFairnessGain=service.fairness-before.fairness; row.acceptedTotalGainBits=service.totalBits-before.totalBits;
        row.candidateFamilies=strjoin(joint.sources,'|'); evidence=leo_append_struct(evidence,row);
    end
    priceLower=leo_evaluate_quadratic_service(d,proxy.lower,priceX); priceService=problem.evaluate(priceX);
    if leo_service_is_better(priceService,service,phase,s0)
        bestX=priceX; service=priceService; history.priceScheduleAccepted(k)=1;
        checkpoints=point(checkpoints,service,k,'price_schedule');
    end
    starts={priceX,bestX}; started=tic;
    for j=1:2
        if j==2 && isequal(starts{1},starts{2}), continue; end
        recovered=leo_recover_schedule(problem,starts{j},phase,s0,o,k,budget);
        history.recoveryEvaluations(k)=history.recoveryEvaluations(k)+recovered.evaluations;
        history.crossEvaluations(k)=history.crossEvaluations(k)+recovered.crossEvaluations;
        history.acceptedMoves(k)=history.acceptedMoves(k)+recovered.acceptedMoves;
        if leo_service_is_better(recovered.service,service,phase,s0)
            bestX=recovered.x; service=recovered.service; history.recoveryAccepted(k)=history.recoveryAccepted(k)+1;
            checkpoints=point(checkpoints,service,k,'recovery');
        end
    end
    history.recoverySeconds(k)=toc(started);
    if ~isFair
        if service.totalBits-roundStartTotal>c.gainAbsoluteTolerance*max(1,roundStartTotal), stagnantRounds=0;
        else, stagnantRounds=stagnantRounds+1; end
    end
    candidate=leo_original_upper_bound(d,cache,lambda,phase,s0); if candidate.value<upper.value, upper=candidate; end
    step=initialStep/k^o.stepExponent;
    % Stage 1 feeds ORIGINAL attained service to the smoothed relative-deficit coordinator.
    feedback=priceLower.userBits; if isFair, feedback=service.userBits; end
    [lambda,priceState]=leo_update_prices(lambda,feedback,d.qosTargetBits,sAux,step,phase,o,priceState);
    history.lambdaNext(:,k)=lambda; history.lowerUserBits(:,k)=priceLower.userBits;
    history.priceX(:,:,k)=priceX; history.step(k)=step; history.priceFairness(k)=priceService.fairness;
    history.priceTotalBits(k)=priceService.totalBits; history.savedFairness(k)=service.fairness;
    history.savedTotalBits(k)=service.totalBits; history.upperBound(k)=upper.value; history.proxyEpoch(k)=epoch;
    history.elapsedSeconds(k)=toc(budget.timer); history.trustRadius(k)=mean(radius); history.completePriceRound(k)=all(snap.solved);
    history.stage2StagnantRounds(k)=stagnantRounds;
    [convergence,converged]=leo_v16_convergence_step(o,phase,service,k,convergence);
    history.stableWindows(k)=convergence.stableWindows; history.lastWindowGain(k)=convergence.lastWindowGain;
    completed=k; snap.proposed=priceX; snapshots{end+1}=snap;
    if numel(snapshots)>o.audit.snapshots, snapshots(1)=[]; end
    leo_v16_save_progress(o,phase,bestX,service,history,convergence,k);
    if o.verbose && (k==1 || mod(k,5)==0 || k==rounds)
        limit=sprintf('%d',rounds); if unlimited, limit='until-convergence'; end
        fprintf('  Proxy %-10s %d/%s: s=%.9g, V=%.6g Mbit, sum(lambda)=%.8g, joint=%d, radius=%.3g, novel=%d, escape=%d\n', ...
            phase,k,limit,service.fairness,service.totalBits/1e6,history.lambdaSum(k),joint.accepted,mean(radius), ...
            history.novelCandidates(k),history.trustEscape(k));
    end
    if unlimited && o.verbose && (mod(k,conv.windowRounds)==0 || converged)
        fprintf('    convergence: stable windows %d/%d, window gain %.6g, tolerance %.6g, minimum rounds %d.\n', ...
            convergence.stableWindows,conv.stableWindows,convergence.lastWindowGain, ...
            convergence.lastWindowTolerance,convergence.minimumRounds);
    end
    if converged, status='objective_plateau'; break; end
    if o.refreshEvery>0 && mod(k,o.refreshEvery)==0 && (unlimited || k<rounds)
        started=tic; proxy=leo_v12_build_service_surrogates(problem,'current_schedule',bestX);
        history.proxyRefreshSeconds(k)=toc(started); epoch=epoch+1;
        errors(epoch)=proxy.error.optimalFairnessGapBound; touch(epoch)=proxy.referenceTouchMaxAbsBits;
    end
end
for name=fieldnames(history).'
    if strcmp(name{1},'priceX'), history.(name{1})=history.(name{1})(:,:,1:completed);
    else, history.(name{1})=history.(name{1})(:,1:completed); end
end
[stopping,~]=leo_search_stopping(o,phase,service,upper.value,toc(budget.timer),completed,stopping); stopping.reason=status;
stopping.convergence=convergence;
value=service.fairness; if ~isFair, value=service.normalizedThroughput; end
result=struct('x',bestX,'service',service,'fairnessFloor',s0,'rounds',completed,'status',status,'history',history, ...
 'upperBound',upper,'absoluteGap',max(0,upper.value-value),'certifiedWithinTolerance',upper.value-value<=o.gapTolerance, ...
 'stopping',stopping,'lambda',lambda,'proxy',proxy,'proxyEpochFairnessErrorBounds',errors, ...
 'proxyEpochTouchErrorsBits',touch,'elapsedAtEndSeconds',toc(budget.timer),'initialService',start.service, ...
 'initialElapsedSeconds',initialSeconds,'initialUpperBound',initialUpper,'iterationKind','price_round', ...
 'sbTrace',firstTrace,'auditSnapshots',{snapshots},'checkpoints',point(checkpoints,service,completed,'end'),'sourceEvidence',evidence);
    function value=polynomial(lower,g)
        value=g.*(lower.aBits(:,m)-lower.bBits(:,:,m)*g);
    end
    function addwork(inner,seconds)
        history.innerSeconds(k)=history.innerSeconds(k)+seconds;
        history.sbSteps(k)=history.sbSteps(k)+inner.sbSteps;
        history.sbTrajectorySteps(k)=history.sbTrajectorySteps(k)+inner.trajectorySteps;
        history.denseDynamicsTerms(k)=history.denseDynamicsTerms(k)+inner.denseTerms;
        history.repairedCandidates(k)=history.repairedCandidates(k)+inner.nRepaired;
        history.maxQuboBits(k)=max(history.maxQuboBits(k),inner.nBits);
        history.innerTabuIterations(k)=history.innerTabuIterations(k)+inner.tabuIterations;
        history.innerTabuCandidates(k)=history.innerTabuCandidates(k)+inner.tabuCandidates;
        history.blockwiseEvaluations(k)=history.blockwiseEvaluations(k)+inner.preselectionEvaluations;
        history.sbRestarts(k)=history.sbRestarts(k)+inner.restarts;
        history.parallelWorkers(k)=max(history.parallelWorkers(k),inner.parallelWorkers);
        history.parallelTasks(k)=history.parallelTasks(k)+inner.parallelTasks;
        history.repairLoss(k)=history.repairLoss(k)+max(0,inner.repairLoss);
        for name={'novelCandidates','trustPathCandidates','trustBridgeCandidates','trustRejectedCandidates'}
            history.(name{1})(k)=history.(name{1})(k)+inner.(name{1});
        end
    end
    function record(family,inner,seconds,actual,estimate)
        row=struct('phase',phase,'round',k,'resource',m,'family',family,'seconds',seconds, ...
         'rawScore',inner.rawScore,'repairedScore',inner.repairedScore,'polishedScore',inner.polishedScore, ...
         'repairLoss',inner.repairLoss,'polishGain',inner.polishGain,'rawLegalFraction',inner.rawLegalFraction, ...
         'rawEncodedLegalFraction',inner.rawEncodedLegalFraction,'rawEnergy',inner.rawEnergy, ...
         'originalWeightedGain',actual,'proxyWeightedGain',estimate,'acceptedFairnessGain',0,'acceptedTotalGainBits',0, ...
         'candidateFamilies',family,'penaltyFactor',local.penaltyFactor);
        evidence=leo_append_struct(evidence,row);
    end
    function h=point(h,s,iteration,kind)
        empty=isempty(h); h=leo_record_search_step(h,s,iteration,toc(budget.timer),NaN);
        if empty, h.kind={}; end
        h.kind{end+1}=kind;
    end
end
