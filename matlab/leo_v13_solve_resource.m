function result = leo_v13_solve_resource(data,lower,m,weights,oldGroup,options,budget)
%LEO_V13_SOLVE_RESOURCE SB/Local/Proxy+Tabu块搜索；可保留不同合法组供原目标验收。
q=leo_build_resource_qubo(data,lower,m,weights,options); old=logical(oldGroup(q.userIds));
score=@(x) q.A.'*double(x)-double(x).'*q.B*double(x)/2;
oldScore=score(old); best=old; bestScore=oldScore; repairs=0;
poolGroups=old; poolSources={'warm_start'};
switch options.innerSolver
    case 'sb'
        seeds=[leo_encode_group_bits(q,old),leo_encode_group_bits(q,false(q.nUsers,1))];
        sb=leo_v8_ballistic_sb(leo_qubo_to_ising(q),options,seeds,budget);
        candidates=[old,false(q.nUsers,1),logical(sb.bits(1:q.nUsers,:))];
        candidates=unique(candidates.','rows').';
        for r=1:size(candidates,2)
            x=leo_repair_group(q,candidates(:,r)); repairs=repairs+any(x~=candidates(:,r));
            remember(x,'sb_repaired');
            if ~leo_budget_expired(budget), x=leo_polish_group(q,x,options.polishMoves); end
            remember(x,'sb_polished');
            value=score(x); if value>bestScore, best=x; bestScore=value; end
        end
    case 'local'
        for r=1:options.localRestarts+2
            if leo_budget_expired(budget), break; end
            if r==1, x=old; elseif r==2, x=false(q.nUsers,1);
            else, x=leo_repair_group(q,rand(q.nUsers,1)<.5); end
            remember(x,'local_start'); x=leo_polish_group(q,x,options.polishMoves);
            remember(x,'local_polished');
            value=score(x); if value>bestScore, best=x; bestScore=value; end
        end
    case 'tabu'
        search=leo_proxy_tabu_group(q,old,options,budget);
        best=search.x; bestScore=search.score; repairs=search.repaired;
        if isfield(search,'candidateGroups')
            for j=1:size(search.candidateGroups,2), remember(search.candidateGroups(:,j),'tabu_trajectory'); end
        end
    otherwise
        result=leo_v8_solve_resource(data,lower,m,weights,oldGroup,options,budget); return;
end
result=struct('x',false(data.shape(1),1),'bits',leo_encode_group_bits(q,best), ...
    'score',bestScore,'oldScore',oldScore,'sbSteps',0,'nRepaired',repairs,'nBits',q.nBits,'optimal',false);
result.x(q.userIds)=best;
ref=leo_proxy_refinement_options(); if isfield(options,'refinement'), ref=options.refinement; end
if ref.candidatePool
    remember(best,'proxy_best'); pool=leo_v13_candidate_pool(q,poolGroups,poolSources,ref.poolSize);
    if ~any(all(bsxfun(@eq,pool.groups,best),1))
        pool.groups(:,end)=best; pool.sources{end}='proxy_best';
    end
    result.candidateGroups=false(data.shape(1),size(pool.groups,2));
    result.candidateGroups(q.userIds,:)=pool.groups; result.candidateSources=pool.sources;
end
if strcmp(options.innerSolver,'sb')
    result.sbSteps=sb.steps; result.energyHistory=sb.history; result.energyScale=sb.energyScale; result.trajectories=sb.trajectories;
end
if strcmp(options.innerSolver,'tabu')
    result.tabuIterations=search.iterations; result.tabuCandidates=search.candidates;
end
    function remember(x,source)
        if ~isfield(options,'refinement') || ~options.refinement.candidatePool, return; end
        poolGroups(:,end+1)=x; poolSources{end+1}=source;
    end
end
