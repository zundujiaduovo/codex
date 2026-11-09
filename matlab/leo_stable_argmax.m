function index = leo_stable_argmax(values,relativeTolerance)
%LEO_STABLE_ARGMAX 数值并列时取输入中最小编号，避免浮点末位改变离线码本。
if nargin<2, relativeTolerance=1e-10; end
assert(isvector(values) && ~isempty(values) && all(isfinite(values)));
assert(isscalar(relativeTolerance) && relativeTolerance>=0 && isfinite(relativeTolerance));
best=max(values); tolerance=relativeTolerance*max(1,max(abs(values)));
index=find(values>=best-tolerance,1,'first');
end
