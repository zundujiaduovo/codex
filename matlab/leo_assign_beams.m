function b = leo_assign_beams(p,r,g,cb)
%LEO_ASSIGN_BEAMS [G5-G6] 整资源同一码字最大化最差增益，只做物理过滤。
% 接口标注：
% 输入：p/r/g/cb：参数、固定资源、预测几何、冻结码本。
% 输出：b：K×M 可用掩码/预指派码字，以及 K×NB×T 实际增益。
K = p.system.K; T = p.time.nSlots; M = r.nResources;
b.response = complex(zeros(p.array.nElements,K,T));
b.gain = zeros(K,cb.nBeams,T);        % |a_i^H f_b|^2，不额外乘 Na
for t = 1:T
    b.response(:,:,t) = leo_array_response(p,g.directionArray(:,:,t));
    b.gain(:,:,t) = abs(b.response(:,:,t)'*cb.F).^2;
end
b.available = false(K,M);
b.index = zeros(K,M);                % 不可用位置编号为 0，不索引码本
b.worstGain = zeros(K,M);
for m = 1:M
    slots = r.slots{m};
    slots = slots(r.dataDurationS(slots)>0);
    if isempty(slots), continue; end
    validGeometry = all(g.visible(:,slots),2);
    worst = min(b.gain(:,:,slots),[],3);
    [best,index] = max(worst,[],2);   % MATLAB max 并列时取最小编号
    valid = validGeometry & best>=p.coverage.minGain;
    b.available(:,m) = valid;
    b.index(valid,m) = index(valid);
    b.worstGain(:,m) = best;
end
end
