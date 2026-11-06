function hard = leo_build_hard_constraints(p,r,b)
%LEO_BUILD_HARD_CONSTRAINTS O1：x(:) 按 MATLAB 列优先，资源内用户连续。
% 接口标注：
% 输入：p/r/b：人数/固定块/波束可用性。
% 输出：hard：x(:) 的稀疏 A/rhs、上下界、整数索引；列优先排列。
K = p.system.K; M = r.nResources; n = K*M;
hard.shape = [K,M];
hard.index = reshape(1:n,K,M);
hard.lower = zeros(n,1);
hard.upper = double(b.available(:)); % x<=v；不可用变量固定为零，保留用户需求
hard.integerIndices = (1:n).';
hard.capacityRows = (1:M).';
rows = repmat(1:M,K,1);
A = sparse(rows(:),(1:n).',ones(n,1),M,n);
rhs = repmat(p.system.maxStreams,M,1);
beamRow = []; beamResource = []; beamCode = [];
for m = 1:M
    ids = unique(b.index(b.available(:,m),m));
    for beam = ids.'
        users = find(b.available(:,m) & b.index(:,m)==beam);
        row = size(A,1)+1;
        A(row,hard.index(users,m)) = 1;
        rhs(row,1) = 1;
        beamRow(end+1,1) = row; %#ok<AGROW>
        beamResource(end+1,1) = m; %#ok<AGROW>
        beamCode(end+1,1) = beam; %#ok<AGROW>
    end
end
hard.A = A; hard.rhs = rhs;
hard.beamRows = beamRow;
hard.beamResource = beamResource;
hard.beamCode = beamCode;
% 由于 L*p0<=Pmax 已校验，人数约束蕴含平均功率约束，不重复添加。
end
