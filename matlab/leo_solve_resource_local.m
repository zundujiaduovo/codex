function result = leo_solve_resource_local(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE_LOCAL 第 13.3 节：同一二次代理的多起点可行 add/drop/swap。
% 输入输出与 leo_solve_resource_sb 相同；保留旧组，允许空组，不调用 SB。
if nargin<7, budget = []; end
setupTimer=tic;
q = leo_build_resource_qubo(data,lower,m,weights,options);
setupSeconds=toc(setupTimer); postTimer=tic;
old = logical(oldGroup(q.userIds)); raw=[old,false(q.nUsers,1)]; sources={'warm_start','empty'};
for r = 1:options.localRestarts+2
    if leo_budget_expired(budget), break; end
    if r<=2, continue; end
    raw(:,end+1)=rand(q.nUsers,1)<.5; sources{end+1}='local'; %#ok<AGROW>
end
archive=leo_resource_candidate_archive(q,old,raw,sources,options,budget);
best=archive.best; bestScore=archive.bestScore; oldScore=archive.oldScore;
result.x = false(data.shape(1),1); result.x(q.userIds) = best;
result.bits = leo_encode_group_bits(q,best);
result.score = bestScore; result.oldScore = oldScore;
result.sbSteps = 0; result.nRepaired = archive.nRepaired; result.nBits = q.nBits; result.optimal = false;
result.candidateGroups=false(data.shape(1),size(archive.groups,2));
result.candidateGroups(q.userIds,:)=archive.groups;
result.candidateSources=archive.sources;
result.diagnostics=rmfield(archive,{'best','groups','scores','sources'});
result.diagnostics.quboSetupSeconds=setupSeconds;
result.diagnostics.solverDynamicsSeconds=0;
result.diagnostics.candidatePostprocessSeconds=toc(postTimer);
end
