function result = leo_v13_solve_resource(data,lower,m,weights,oldGroup,options,budget)
%LEO_V13_SOLVE_RESOURCE 与冻结内层同一候选/随机流/动作顺序，只向量化局部扫描。
q=leo_build_resource_qubo(data,lower,m,weights,options); old=logical(oldGroup(q.userIds));
score=@(x) q.A.'*double(x)-double(x).'*q.B*double(x)/2;
oldScore=score(old); best=old; bestScore=oldScore; repairs=0;
switch options.innerSolver
    case 'sb'
        seeds=[leo_encode_group_bits(q,old),leo_encode_group_bits(q,false(q.nUsers,1))];
        sb=leo_v8_ballistic_sb(leo_qubo_to_ising(q),options,seeds,budget);
        candidates=[old,false(q.nUsers,1),logical(sb.bits(1:q.nUsers,:))];
        candidates=unique(candidates.','rows').';
        for r=1:size(candidates,2)
            x=leo_repair_group(q,candidates(:,r)); repairs=repairs+any(x~=candidates(:,r));
            if ~leo_budget_expired(budget), x=leo_polish_group(q,x,options.polishMoves); end
            value=score(x); if value>bestScore, best=x; bestScore=value; end
        end
    case 'local'
        for r=1:options.localRestarts+2
            if leo_budget_expired(budget), break; end
            if r==1, x=old; elseif r==2, x=false(q.nUsers,1);
            else, x=leo_repair_group(q,rand(q.nUsers,1)<.5); end
            x=leo_polish_group(q,x,options.polishMoves);
            value=score(x); if value>bestScore, best=x; bestScore=value; end
        end
    case 'tabu'
        search=leo_proxy_tabu_group(q,old,options,budget);
        best=search.x; bestScore=search.score; repairs=search.repaired;
    otherwise
        result=leo_v8_solve_resource(data,lower,m,weights,oldGroup,options,budget); return;
end
result=struct('x',false(data.shape(1),1),'bits',leo_encode_group_bits(q,best), ...
    'score',bestScore,'oldScore',oldScore,'sbSteps',0,'nRepaired',repairs,'nBits',q.nBits,'optimal',false);
result.x(q.userIds)=best;
if strcmp(options.innerSolver,'sb')
    result.sbSteps=sb.steps; result.energyHistory=sb.history; result.energyScale=sb.energyScale; result.trajectories=sb.trajectories;
end
if strcmp(options.innerSolver,'tabu')
    result.tabuIterations=search.iterations; result.tabuCandidates=search.candidates;
end
end
