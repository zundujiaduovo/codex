function x = leo_repair_group(qubo,x)
%LEO_REPAIR_GROUP 按最小二次收益损失删除冲突者，再删除超出容量者。
% 接口标注：
% 输入：qubo：收益/冲突/容量信息；x：可能冲突的局部用户位。
% 输出：x：通过删除最小收益损失用户得到的合法组。
x = logical(x(:)); assert(numel(x)==qubo.nUsers);
while true
    selected = find(x);
    conflict = false(size(x));
    for b = unique(qubo.beamIndex(selected)).'
        members = find(x & qubo.beamIndex==b);
        if numel(members)>1, conflict(members) = true; end
    end
    if any(conflict)
        candidates = find(conflict);
    elseif sum(x)>qubo.maxStreams
        candidates = selected;
    else
        break;
    end
    loss = qubo.A-qubo.B*double(x);
    [~,j] = min(loss(candidates)); x(candidates(j)) = false;
end
end
