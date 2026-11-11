function data = leo_v12_diagnostic_data(report)
%LEO_V12_DIAGNOSTIC_DATA 原生迭代及已记录工作量；未知细分计数/耗时保持NaN。
data=struct('iterations',struct([]),'phases',struct([]),'workload',struct([]),'targets',struct([]));
for j=1:numel(report.records)
    r=report.records(j); result=report.solutions{j}; first=numel(data.phases)+1;
    if ~strcmp(r.status,'completed') || isempty(result), continue; end
    for phase=1:2
        stage=result.(sprintf('stage%d',phase)); h=stage.history; isPrice=isfield(stage,'rounds');
        kind=stage.iterationKind; floorValue=0; if phase==2, floorValue=result.fairnessFloor; end
        if isPrice, iterations=stage.rounds; kind='price_round_attempt'; else, iterations=stage.iterations; end
        t0=NaN;
        if isfield(stage,'initialElapsedSeconds'), t0=stage.initialElapsedSeconds;
        elseif isfield(h,'iteration') && ~isempty(h.iteration) && h.iteration(1)==0, t0=h.elapsedSeconds(1); end
        candidates=NaN; resourceSolves=0; sbSteps=0; trajectorySteps=0; denseTerms=0; maxBits=0;
        if isPrice
            candidates=0; resourceSolves=sum(h.resourcesSolved); sbSteps=sum(h.sbSteps);
            trajectorySteps=sbSteps*result.options.sbTrajectories;
            if isfield(result.options,'coordination'), trajectorySteps=sum(h.sbTrajectorySteps); end
            denseTerms=total(h,'denseDynamicsTerms'); if sbSteps==0, denseTerms=0; end
            maxBits=maximum(h,'maxQuboBits');
            add(0,t0,stage.initialService,0,NaN,0,0,0,'initial');
        elseif isfield(h,'evaluations') && ~isempty(h.evaluations), candidates=h.evaluations(end)-h.evaluations(1); end
        cumulative=0;
        for k=1:numel(h.elapsedSeconds)
            if isPrice
                n=k; increment=h.recoveryEvaluations(k)+h.blockwiseEvaluations(k)+1;
                if isfield(h,'candidateGapEvaluations'), increment=increment+h.candidateGapEvaluations(k); end
                if isfield(h,'jointEvaluations'), increment=increment+h.jointEvaluations(k); end
                cumulative=cumulative+increment; candidates=cumulative;
                complete=double(h.completePriceRound(k)); solves=h.resourcesSolved(k); steps=h.sbSteps(k);
                terms=NaN; if isfield(h,'denseDynamicsTerms'), terms=h.denseDynamicsTerms(k); end
            else
                n=h.iteration(k); cumulative=h.evaluations(k)-h.evaluations(1);
                complete=NaN; solves=0; steps=0; terms=0;
            end
            service=struct('fairness',h.savedFairness(k),'totalBits',h.savedTotalBits(k));
            add(n,h.elapsedSeconds(k),service,cumulative,complete,solves,steps,terms,'iteration');
        end
        if ~isPrice && isfield(stage,'evaluations')
            candidates=stage.evaluations;
            add(iterations,stage.elapsedAtEndSeconds,stage.service,candidates,NaN,0,0,0,'phase_end');
        end
        row=struct('method',r.method,'seed',r.seed,'phase',phase,'iterationKind',kind, ...
            'nativeIterations',iterations,'completePriceRounds',NaN,'recordedOriginalCandidateScores',candidates, ...
            'resourceSolves',resourceSolves,'sbIntegrationSteps',sbSteps,'sbTrajectorySteps',trajectorySteps, ...
            'denseDynamicsTerms',denseTerms,'maxQuboBits',maxBits,'innerSeconds',0, ...
            'innerTabuIterations',0,'innerTabuCandidates',0, ...
            'extraInnerCalls',0,'candidateCutRefreshes',0,'candidateCutSeconds',0, ...
            'poolAccepted',0,'bottleneckAccepted',0,'retangentAccepted',0,'priceScheduleAccepted',0,'recoveryAccepted',0, ...
            'originalSelectionSeconds',NaN,'recoverySeconds',NaN,'proxyRefreshSeconds',0,'proxyRefreshes',0, ...
            'fixedFairnessFloor',floorValue,'status',stage.status);
        if isPrice
            for name={'extraInnerCalls','candidateCutRefreshes','candidateCutSeconds','poolAccepted', ...
                    'bottleneckAccepted','retangentAccepted','priceScheduleAccepted','recoveryAccepted'}
                row.(name{1})=total(h,name{1});
            end
            row.innerTabuIterations=total(h,'innerTabuIterations'); row.innerTabuCandidates=total(h,'innerTabuCandidates');
            row.completePriceRounds=sum(h.completePriceRound);
            row.innerSeconds=total(h,'innerSeconds'); row.originalSelectionSeconds=total(h,'originalSelectionSeconds');
            row.recoverySeconds=total(h,'recoverySeconds'); row.proxyRefreshSeconds=total(h,'proxyRefreshSeconds');
            row.proxyRefreshes=max(0,numel(stage.proxyEpochFairnessErrorBounds)-1);
        end
        data.phases=leo_append_struct(data.phases,row);
    end
    p=data.phases(first:end); info=whos('result');
    row=struct('method',r.method,'seed',r.seed,'fairness',r.fairness,'totalBits',r.totalBits, ...
        'fairnessFloor',result.fairnessFloor,'commonSeconds',r.commonSeconds,'proxyPreparationSeconds',r.proxyPreparationSeconds, ...
        'searchSeconds',r.searchSeconds,'endToEndSeconds',r.endToEndSeconds, ...
        'phase1Iterations',p(1).nativeIterations,'phase2Iterations',p(2).nativeIterations, ...
        'phase1Kind',p(1).iterationKind,'phase2Kind',p(2).iterationKind, ...
        'recordedOriginalCandidateScores',sum([p.recordedOriginalCandidateScores]), ...
        'resourceSolves',sum([p.resourceSolves]),'sbIntegrationSteps',sum([p.sbIntegrationSteps]), ...
        'sbTrajectorySteps',sum([p.sbTrajectorySteps]),'denseDynamicsTerms',sum([p.denseDynamicsTerms]), ...
        'innerTabuIterations',sum([p.innerTabuIterations]),'innerTabuCandidates',sum([p.innerTabuCandidates]), ...
        'extraInnerCalls',sum([p.extraInnerCalls]),'candidateCutRefreshes',sum([p.candidateCutRefreshes]), ...
        'poolAccepted',sum([p.poolAccepted]),'bottleneckAccepted',sum([p.bottleneckAccepted]), ...
        'retangentAccepted',sum([p.retangentAccepted]),'priceScheduleAccepted',sum([p.priceScheduleAccepted]), ...
        'recoveryAccepted',sum([p.recoveryAccepted]), ...
        'maxQuboBits',max([p.maxQuboBits]),'innerSeconds',sum([p.innerSeconds]), ...
        'proxyBuildAndRefreshSeconds',NaN,'retainedResultBytes',info.bytes, ...
        'censoredByTime',any(cellfun(@(s) ~isempty(strfind(s,'time_limit')),{p.status})), ...
        'counterScope','Original candidate scores exclude initialization, selected-candidate verification and bounds; dense terms count N^2*R per SB force step, not all FLOPs; retained bytes are not peak memory.');
    if ~r.usesQuadraticProxy, row.proxyBuildAndRefreshSeconds=0;
    elseif isfield(result,'initialProxySeconds')
        row.proxyBuildAndRefreshSeconds=result.initialProxySeconds+result.stage2ProxySeconds+sum([p.proxyRefreshSeconds])+sum([p.candidateCutSeconds]);
    end
    data.workload=leo_append_struct(data.workload,row);
end
trace=leo_v12_trace_data(report); upper=leo_fairness_limit(report.problemData);
if isfield(report,'fairnessCertificate'), upper=report.fairnessCertificate.upper; end
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    rows=trace.progress(strcmp({trace.progress.method},r.method) & [trace.progress.seed]==r.seed);
    for fraction=[.90,.95,.99]
        target=fraction*upper; reached=find([rows.fairness]>=target,1); seconds=NaN;
        if ~isempty(reached), seconds=rows(reached).seconds; end
        row=struct('method',r.method,'seed',r.seed,'upperBoundFraction',fraction,'fairnessUpper',upper, ...
            'fairnessTarget',target,'reached',~isempty(reached),'firstRecordedSeconds',seconds, ...
            'scope','One common ORIGINAL fairness target. First observed attainment; no interpolation or filling missing targets with the time budget.');
        data.targets=leo_append_struct(data.targets,row);
    end
end
    function add(n,seconds,service,work,complete,solves,steps,terms,pointKind)
        row=struct('method',r.method,'seed',r.seed,'phase',phase,'nativeIteration',n,'iterationKind',kind, ...
            'pointKind',pointKind, ...
            'seconds',r.commonSeconds+r.proxyPreparationSeconds+seconds,'phaseSeconds',seconds-t0, ...
            'recordedOriginalCandidateScores',work,'fairness',service.fairness,'totalBits',service.totalBits, ...
            'fixedFairnessFloor',floorValue,'completePriceRound',complete,'resourceSolvesThisRound',solves, ...
            'sbIntegrationStepsThisRound',steps,'denseDynamicsTermsThisRound',terms);
        data.iterations=leo_append_struct(data.iterations,row);
    end
end
function v=total(h,name)
v=NaN; if isfield(h,name), v=sum(h.(name)); end
end
function v=maximum(h,name)
v=NaN; if isfield(h,name), v=max([0,h.(name)]); end
end
