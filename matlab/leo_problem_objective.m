function value = leo_problem_objective(z,data,stage)
%LEO_PROBLEM_OBJECTIVE 最小化接口：阶段 1 为 -s，阶段 2 为 -sum(D)/Dref。
% 接口标注：
% 输入：z：完整优化向量；data：原模型；stage：1 或 2。
% 输出：value：最小化形式的负公平/负归一化总服务。
n = prod(data.shape);
assert(isvector(z) && all(isfinite(z(:))));
if stage==1
    assert(numel(z)==n+1);
    value = -z(end);
elseif stage==2
    assert(numel(z)==n);
    result = leo_evaluate_service(data,reshape(z,data.shape),false);
    value = -result.normalizedThroughput;
else
    error('阶段编号必须是 1 或 2。');
end
end
