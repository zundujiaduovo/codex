function ising = leo_qubo_to_ising(qubo)
%LEO_QUBO_TO_ISING Q5：z=(1+sigma)/2，E=C'+h'*sigma+sigma'*J*sigma/2。
% 接口标注：
% 输入：qubo：E=C+z'Qsym z 的对称二次编码。
% 输出：ising：J/h/constant，E=C'+h'sigma+sigma'J sigma/2。
% J 对称、零对角；SB 的力须与此正号能量的梯度方向相反。
Q = qubo.Qsym;
assert(isequal(Q,Q.') && all(isfinite(Q(:))));
ising.J = (Q-diag(diag(Q)))/2;
ising.h = Q*ones(size(Q,1),1)/2;
ising.constant = qubo.constant+(sum(Q(:))+trace(Q))/4;
ising.nBits = size(Q,1);
end
