function result = leo_v8_solve_resource_local(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE_LOCAL 第 13.3 节：同一二次代理的多起点可行 add/drop/swap。
% 输入输出与 leo_v8_solve_resource_sb 相同；保留旧组，允许空组，不调用 SB。
if nargin<7, budget = []; end
q = leo_build_resource_qubo(data,lower,m,weights,options);
old = logical(oldGroup(q.userIds)); best = old;
score = @(x) q.A.'*double(x)-double(x).'*q.B*double(x)/2;
oldScore = score(old); bestScore = oldScore;
for r = 1:options.localRestarts+2
    if leo_budget_expired(budget), break; end
    if r==1, x = old;
    elseif r==2, x = false(q.nUsers,1);
    else, x = leo_repair_group(q,rand(q.nUsers,1)<.5); end
    x = leo_v8_polish_group(q,x,options.polishMoves);
    value = score(x);
    if value>bestScore, best = x; bestScore = value; end
end
result.x = false(data.shape(1),1); result.x(q.userIds) = best;
result.bits = leo_encode_group_bits(q,best);
result.score = bestScore; result.oldScore = oldScore;
result.sbSteps = 0; result.nRepaired = 0; result.nBits = q.nBits; result.optimal = false;
end
