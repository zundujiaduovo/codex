function x = leo_polish_group(qubo,x,maxMoves)
%LEO_POLISH_GROUP 可行组上的二次收益 add/drop/swap，严格单调、有限动作。
% 接口标注：
% 输入：qubo：固定二次目标；x：合法局部组；maxMoves：最大改进动作数。
% 输出：x：可行 add/drop/swap 改进后的组，代理收益不下降。
x = logical(x(:));
if isempty(x), return; end
for step = 1:maxMoves
    marginal = qubo.A-qubo.B*double(x);
    chosen = find(x); absent = find(~x);
    % 与旧实现同一顺序：先删除，再按未选用户依次添加/替换。
    % max 的首个最大值保留旧版严格 > 的平局规则。
    conflicts=bsxfun(@eq,qubo.beamIndex(absent),qubo.beamIndex(chosen).');
    count=sum(conflicts,2); additions=marginal(absent);
    additions(count>0 | numel(chosen)>=qubo.maxStreams)=-Inf;
    changes=bsxfun(@minus,marginal(absent),marginal(chosen).')+qubo.B(absent,chosen);
    allowed=bsxfun(@or,count==0,bsxfun(@and,count==1,conflicts));
    changes(~allowed)=-Inf;
    choices=[additions,changes].';
    [gain,at]=max([-marginal(chosen);choices(:)]);
    if gain<=1e-13*max(1,sum(abs(qubo.A))), break; end
    add=0; drop=0;
    if at<=numel(chosen)
        drop=chosen(at);
    else
        index=at-numel(chosen)-1; row=floor(index/(numel(chosen)+1))+1;
        column=mod(index,numel(chosen)+1); add=absent(row);
        if column>0, drop=chosen(column); end
    end
    if drop>0, x(drop) = false; end
    if add>0, x(add) = true; end
end
end
