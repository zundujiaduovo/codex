function result = leo_solve_resource_sb(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE_SB 资源 QUBO -> Ising -> 多轨迹 SB -> 修复 -> 代理计分。
% 接口标注：
% 输入：data/lower/m/weights：内层 L4；oldGroup：K×1；options/budget：搜索配置。
% 输出：result：合法 K×1 组、代理分数、SB 步数、实际修复数及 energyHistory；保留旧组。
% 同一组价格下保留旧组和空组，保证内层返回值不劣于这两个候选。
if nargin<7, budget = []; end
setupTimer=tic;
qubo = leo_build_resource_qubo(data,lower,m,weights,options);
old = logical(oldGroup(qubo.userIds));
seeds = [leo_encode_group_bits(qubo,old),leo_encode_group_bits(qubo,false(qubo.nUsers,1))];
for j=1:min(options.sbPerturbedSeeds,max(0,options.sbTrajectories-2))
    perturbed=old;
    if ~isempty(old)
        flips=randperm(numel(old),min(numel(old),1+mod(j-1,3)));
        perturbed(flips)=~perturbed(flips);
    end
    perturbed=leo_repair_group(qubo,perturbed);
    seeds(:,end+1)=leo_encode_group_bits(qubo,perturbed); %#ok<AGROW>
end
ising = leo_qubo_to_ising(qubo);
setupSeconds=toc(setupTimer); dynamicsTimer=tic;
sb = leo_ballistic_sb(ising,options,seeds,budget);
dynamicsSeconds=toc(dynamicsTimer); postTimer=tic;
candidates = [old,false(qubo.nUsers,1),logical(sb.bits(1:qubo.nUsers,:))];
origins=[{'warm_start','empty'},repmat({'sb'},1,size(sb.bits,2))];
archive=leo_resource_candidate_archive(qubo,old,candidates,origins,options,budget);
best=archive.best; bestScore=archive.bestScore;
result.x = false(data.shape(1),1); result.x(qubo.userIds) = best;
result.bits = leo_encode_group_bits(qubo,best);
result.score = bestScore;
result.oldScore = group_score(qubo,old);
result.sbSteps = sb.steps;
result.nRepaired = archive.nRepaired;
result.candidateGroups=false(data.shape(1),size(archive.groups,2));
result.candidateGroups(qubo.userIds,:)=archive.groups;
result.candidateSources=archive.sources;
result.diagnostics=rmfield(archive,{'best','groups','scores','sources'});
result.diagnostics.quboSetupSeconds=setupSeconds;
result.diagnostics.solverDynamicsSeconds=dynamicsSeconds;
result.diagnostics.candidatePostprocessSeconds=toc(postTimer);
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
