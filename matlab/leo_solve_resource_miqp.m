function result = leo_solve_resource_miqp(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE_MIQP 第 13.3 节：Gurobi 求解相同 L4 的受约束二元 MIQP。
% 输入输出与 SB 内层一致；需要用户已安装并授权 Gurobi MATLAB 接口。
% 不存在求解器时明确报 unavailable，不以局部搜索冒充 MIQP。
if nargin<7, budget = []; end
if exist('gurobi','file')==0, error('leo:solverUnavailable','Gurobi MATLAB interface is unavailable.'); end
q = leo_build_resource_qubo(data,lower,m,weights,options);
old = logical(oldGroup(q.userIds)); best = old;
score = @(x) q.A.'*double(x)-double(x).'*q.B*double(x)/2;
oldScore = score(old); bestScore = oldScore; optimal = false;
if q.nUsers>0 && ~leo_budget_expired(budget)
    beams = unique(q.beamIndex);
    model.A = sparse([ones(1,q.nUsers);double(bsxfun(@eq,beams,q.beamIndex.'))]);
    model.rhs = [q.maxStreams;ones(numel(beams),1)];
    model.sense = repmat('<',size(model.A,1),1);
    model.Q = sparse(q.B/2); model.obj = -q.A;
    model.lb = zeros(q.nUsers,1); model.ub = ones(q.nUsers,1);
    model.vtype = repmat('B',q.nUsers,1); model.modelsense = 'min'; model.start = double(old);
    params.OutputFlag = 0; params.NonConvex = 2; params.Threads = 1;
    params.Seed = mod(options.seed,2^31-1);
    if isempty(budget), params.TimeLimit = options.maxSeconds;
    else, params.TimeLimit = max(.001,budget.seconds-toc(budget.timer)); end
    solved = gurobi(model,params);
    optimal = strcmp(solved.status,'OPTIMAL');
    if isfield(solved,'x') && all(abs(solved.x-round(solved.x))<1e-6)
        x = leo_repair_group(q,round(solved.x)); value = score(x);
        if value>bestScore, best = x; bestScore = value; end
    end
end
result.x = false(data.shape(1),1); result.x(q.userIds) = best;
result.bits = leo_encode_group_bits(q,best);
result.score = bestScore; result.oldScore = oldScore;
result.sbSteps = 0; result.nRepaired = 0; result.nBits = q.nBits; result.optimal = optimal;
end
