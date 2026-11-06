function z = leo_encode_group_bits(qubo,x)
%LEO_ENCODE_GROUP_BITS 在修复用户组后重新编码松弛位，绝不沿用 SB 原始松弛位。
% 接口标注：
% 输入：qubo：局部编码；x：nUsers×1 合法用户组。
% 输出：z：用户位及重新编码的容量松弛位；二元列向量。
x = logical(x(:));
assert(numel(x)==qubo.nUsers && sum(x)<=qubo.maxStreams);
assert(numel(unique(qubo.beamIndex(x)))==sum(x));
if qubo.capacityIncluded
    slack = qubo.maxStreams-sum(x);
    u = mod(floor(slack./qubo.slackWeights),2);
else
    u = zeros(0,1);
end
z = [double(x);u];
end
