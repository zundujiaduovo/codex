function x = leo_polish_group(qubo,x,maxMoves)
%LEO_POLISH_GROUP 可行组上的二次收益 add/drop/swap，严格单调、有限动作。
% 接口标注：
% 输入：qubo：固定二次目标；x：合法局部组；maxMoves：最大改进动作数。
% 输出：x：可行 add/drop/swap 改进后的组，代理收益不下降。
x = logical(x(:));
for step = 1:maxMoves
    marginal = qubo.A-qubo.B*double(x);
    gain = 0; add = 0; drop = 0;
    chosen = find(x); absent = find(~x);
    for j = chosen.'
        if -marginal(j)>gain, gain = -marginal(j); drop = j; add = 0; end
    end
    for i = absent.'
        conflicts = chosen(qubo.beamIndex(chosen)==qubo.beamIndex(i));
        if isempty(conflicts) && numel(chosen)<qubo.maxStreams && marginal(i)>gain
            gain = marginal(i); add = i; drop = 0;
        end
        for j = chosen.'
            if ~isempty(conflicts) && any(conflicts~=j), continue; end
            change = marginal(i)-marginal(j)+qubo.B(i,j);
            if change>gain, gain = change; add = i; drop = j; end
        end
    end
    if gain<=1e-13*max(1,sum(abs(qubo.A))), break; end
    if drop>0, x(drop) = false; end
    if add>0, x(add) = true; end
end
end
