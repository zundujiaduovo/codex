function result = leo_v8_solve_resource_sb(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE_SB 资源 QUBO -> Ising -> 多轨迹 SB -> 修复 -> 代理计分。
% 接口标注：
% 输入：data/lower/m/weights：内层 L4；oldGroup：K×1；options/budget：搜索配置。
% 输出：result：合法 K×1 组、代理分数、SB 步数、实际修复数及 energyHistory；保留旧组。
% 同一组价格下保留旧组和空组，保证内层返回值不劣于这两个候选。
if nargin<7, budget = []; end
qubo = leo_build_resource_qubo(data,lower,m,weights,options);
old = logical(oldGroup(qubo.userIds));
seeds = [leo_encode_group_bits(qubo,old),leo_encode_group_bits(qubo,false(qubo.nUsers,1))];
ising = leo_qubo_to_ising(qubo);
sb = leo_v8_ballistic_sb(ising,options,seeds,budget);
candidates = [old,false(qubo.nUsers,1),logical(sb.bits(1:qubo.nUsers,:))];
candidates = unique(candidates.','rows').';
best = old; bestScore = group_score(qubo,old);
repairs = 0;
for r = 1:size(candidates,2)
    x = leo_repair_group(qubo,candidates(:,r));
    repairs = repairs+any(x~=candidates(:,r));
    if ~leo_budget_expired(budget), x = leo_v8_polish_group(qubo,x,options.polishMoves); end
    score = group_score(qubo,x);
    if score>bestScore, best = x; bestScore = score; end
end
result.x = false(data.shape(1),1); result.x(qubo.userIds) = best;
result.bits = leo_encode_group_bits(qubo,best);
result.score = bestScore;
result.oldScore = group_score(qubo,old);
result.sbSteps = sb.steps;
result.nRepaired = repairs;
result.nBits = qubo.nBits;
result.optimal = false;
result.energyHistory = sb.history;
result.energyScale = sb.energyScale;
result.trajectories = sb.trajectories;
end

function score = group_score(qubo,x)
x = double(x);
score = qubo.A.'*x-x.'*qubo.B*x/2;
end
