function inner=leo_v13_extra_candidates(data,proxy,m,weights,inner,options,budget,bestX,service,phase,s0)
% 新权重/新切点仅生成额外候选，不替换原价格链的解、分数或下界反馈。
r=options.refinement;
inner.extraInnerCalls=0; inner.cutRefreshes=0; inner.cutSeconds=0; inner.gapEvaluations=0;
inner.gapBefore=0; inner.gapAfter=0;
if ~isfield(inner,'candidateGroups'), inner.candidateGroups=inner.x; inner.candidateSources={'proxy_best'}; end
if r.candidateRefresh && ~leo_budget_expired(budget)
    g=double(inner.x); exact=leo_resource_service(data,m,inner.x);
    predicted=g.*(proxy.lower.aBits(:,m)-proxy.lower.bBits(:,:,m)*g);
    inner.gapEvaluations=1;
    inner.gapBefore=max([0;(exact-predicted)./data.qosTargetBits]);
    if inner.gapBefore>r.gapTrigger
        started=tic; lower=leo_v13_touch_resource(data,proxy,m,inner.x); inner.cutSeconds=toc(started);
        touched=g.*(lower.aBits(:,m)-lower.bBits(:,:,m)*g);
        inner.gapAfter=max(abs(exact-touched)./data.qosTargetBits);
        candidate=leo_v13_solve_resource(data,lower,m,weights,inner.x,options,budget);
        merge(candidate,'retangent'); inner.cutRefreshes=1;
    else
        inner.gapAfter=inner.gapBefore;
    end
end
if r.bottleneckCandidates && ~leo_budget_expired(budget)
    ratios=service.demandRatio;
    if strcmp(phase,'fairness'), distance=ratios-min(ratios);
    else, distance=max(0,ratios-s0); end
    priority=exp(-min(distance/r.bottleneckBand,700)); priority=priority/sum(priority);
    focused=priority./data.qosTargetBits;
    if strcmp(phase,'throughput'), focused=focused+1/data.referenceBits; end
    candidate=leo_v13_solve_resource(data,proxy.lower,m,focused,bestX(:,m),options,budget);
    merge(candidate,'bottleneck');
end
[~,uniqueAt]=unique(inner.candidateGroups.','rows','stable');
inner.candidateGroups=inner.candidateGroups(:,uniqueAt); inner.candidateSources=inner.candidateSources(uniqueAt);
    function merge(c,source)
        inner.extraInnerCalls=inner.extraInnerCalls+1;
        inner.sbSteps=inner.sbSteps+c.sbSteps; inner.nRepaired=inner.nRepaired+c.nRepaired;
        inner.nBits=max(inner.nBits,c.nBits);
        if isfield(c,'tabuIterations')
            inner.tabuIterations=inner.tabuIterations+c.tabuIterations;
            inner.tabuCandidates=inner.tabuCandidates+c.tabuCandidates;
        end
        groups=c.x;
        if isfield(c,'candidateGroups'), groups=c.candidateGroups; end
        inner.candidateGroups=[inner.candidateGroups,groups];
        inner.candidateSources=[inner.candidateSources,repmat({source},1,size(groups,2))];
    end
end
