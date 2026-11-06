function result = leo_solve_resource(data,lower,m,weights,oldGroup,options,budget)
%LEO_SOLVE_RESOURCE 第 13.3 节：相同 L4 内层目标的 SB/局部搜索/MIQP 调度。
% 输入：模型、下界系数、块号、非负权重、旧组、选项、时间预算；输出合法组与代理分数。
if nargin<7, budget = []; end
switch options.innerSolver
    case 'sb'
        result = leo_solve_resource_sb(data,lower,m,weights,oldGroup,options,budget);
    case 'local'
        result = leo_solve_resource_local(data,lower,m,weights,oldGroup,options,budget);
    case 'miqp'
        result = leo_solve_resource_miqp(data,lower,m,weights,oldGroup,options,budget);
    otherwise
        error('未知内层求解器。');
end
end
