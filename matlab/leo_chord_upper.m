function line = leo_chord_upper(S,N,B,a,b)
%LEO_CHORD_UPPER T7-T10：单个速率函数在 [a,b] 上的弦上界与 minimax 切点。
% 接口标注：
% 输入：S/N：固定功率 W；B：Hz；a/b：干扰区间端点 W。
% 输出：line：弦系数、minimax 切点、最大误差 bit/s 与曲率界。
% 仅该区间内有上界保证。主模型始终用 [0,Imax] 覆盖全部合法激活干扰。
assert(isscalar(S) && isscalar(N) && isscalar(a) && isscalar(b));
assert(isfinite(a) && isfinite(b) && 0<=a && a<=b);
ra = leo_rate_and_derivatives(S,N,B,a);
line.intervalW = [a,b];
line.alphaBps = ra;
line.omegaBpsPerW = 0;
line.minimaxReferenceW = a;
line.maxGapBps = 0;
line.curvatureGapBoundBps = 0;
if S==0 || a==b
    % S=0 恒零；零宽区间仅在一个点精确，不把常数延拓宣称为全局上界。
    return;
end
baseN = N+a;
s = S/baseN; h = (b-a)/baseN; C = B/log(2);
assert(isfinite(s) && isfinite(h) && h>0);
v = s*(h/(1+s+h));
logv = log1p(v);
% r(a)-r(b)=C*log1p(s*h/(1+s+h))，避免相近速率相减。
omegaNormalized = C*(logv/h);
line.omegaBpsPerW = omegaNormalized/baseN;
line.alphaBps = ra+line.omegaBpsPerW*a;
% T8 的稳定等价形式，避免 sqrt(...)-S-2N 的消减误差。
% t=v/log1p(v)-1，小 v 用 log1p 差值级数计算。
if v==0
    error('非零区间的弦斜率发生数值下溢。');
elseif v<1e-4
    numerator = v*v*(1/2-v/3+v^2/4-v^3/5+v^4/6);
    t = numerator/logv;
else
    t = v/logv-1;
end
D = h+(1+s+h)*t;
z = 2*D/(s+2+hypot(s+2,2*sqrt(D)));
z = min(h,max(0,z));               % 仅修正舍入导致的端点越界
line.minimaxReferenceW = a+baseN*z;
atReference = leo_rate_and_derivatives(S,N,B,line.minimaxReferenceW);
line.maxGapBps = max(0,line.alphaBps-line.omegaBpsPerW*line.minimaxReferenceW-atReference);
curvatureNormalized = C*(s/(1+s))*((2+s)/(1+s));
line.curvatureGapBoundBps = curvatureNormalized*h*h/8;
assert(isfinite(line.alphaBps) && isfinite(line.omegaBpsPerW) && ...
    isfinite(line.minimaxReferenceW) && isfinite(line.maxGapBps));
end
