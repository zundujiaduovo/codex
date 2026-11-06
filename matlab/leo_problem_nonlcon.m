function [c,ceq] = leo_problem_nonlcon(z,data,stage,s0)
%LEO_PROBLEM_NONLCON 原始非线性累计 QoS，统一 c<=0；不含切线近似。
% 接口标注：
% 输入：z/data：优化向量与原模型；stage：1/2；s0：阶段 2 门槛。
% 输出：c/ceq：归一化非线性约束，c<=0；无额外等式。
n = prod(data.shape);
if stage==1
    assert(numel(z)==n+1);
    target = z(end);
elseif stage==2
    assert(numel(z)==n);
    target = s0;
else
    error('阶段编号必须是 1 或 2。');
end
result = leo_evaluate_service(data,reshape(z(1:n),data.shape),false);
c = target-result.demandRatio;
ceq = [];
end
