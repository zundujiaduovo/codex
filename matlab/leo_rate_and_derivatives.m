function [rate,first,second] = leo_rate_and_derivatives(S,N,B,I)
%LEO_RATE_AND_DERIVATIVES T1：设计速率及对干扰功率 I（W）的导数。
% 接口标注：
% 输入：S/N/I：信号、噪声、干扰功率 W；B：带宽 Hz。
% 输出：rate/first/second：bit/s 及对 W 的一、二阶导数。
% 使用 I/N、S/N 归一化计算；支持标量或可广播数组，不以绝对 eps 判断零功率。
assert(all(isfinite(S(:))) && all(S(:)>=0));
assert(all(isfinite(N(:))) && all(N(:)>0));
assert(isscalar(B) && isfinite(B) && B>0);
assert(all(isfinite(I(:))) && all(I(:)>=0));
s = S./N; u = 1+I./N; C = B/log(2);
assert(all(isfinite(s(:))) && all(isfinite(u(:))),'功率比超过双精度范围。');
rate = C*log1p(s./u);
first = -C*(s./(u+s))./u./N;
second = C*(s./(u+s)).*((2*u+s)./(u+s))./u./u./N./N;
end
