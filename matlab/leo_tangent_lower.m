function line = leo_tangent_lower(S,N,B,referenceW)
%LEO_TANGENT_LOWER T4：ell(I)=alpha-omega*I，保留可能为负的切线值。
% 接口标注：
% 输入：S/N：固定功率 W；B：Hz；referenceW：合法切点 W。
% 输出：line：alphaBps、omegaBpsPerW 与切点速率；ell=alpha-omega*I。
[value,derivative] = leo_rate_and_derivatives(S,N,B,referenceW);
line.referenceW = referenceW;
line.rateAtReferenceBps = value;
line.omegaBpsPerW = -derivative;
line.alphaBps = value+line.omegaBpsPerW.*referenceW;
assert(all(isfinite(line.alphaBps(:))) && all(isfinite(line.omegaBpsPerW(:))));
end
