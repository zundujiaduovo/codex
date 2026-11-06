function x = leo_example_selection(p,r,b)
%LEO_EXAMPLE_SELECTION 仅演示合法选组：按用户编号轮换，同波束至多一人。
% 接口标注：
% 输入：p/r/b：人数上限、资源与可用/波束约束。
% 输出：x：K×M 合法轮换示例，非公平优化结果。
% SINR 必须给定激活组；此函数不是 QoS 调度或公平性算法。
K = p.system.K;
x = false(K,r.nResources);
for m = 1:r.nResources
    order = mod((0:K-1)+(m-1)*p.system.maxStreams,K)+1;
    used = [];
    for i = order
        beam = b.index(i,m);
        if b.available(i,m) && ~any(used==beam)
            x(i,m) = true;
            used(end+1) = beam; %#ok<AGROW>
            if numel(used)==p.system.maxStreams, break; end
        end
    end
end
end
