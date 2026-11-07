function result = leo_evaluate_quadratic_service(data,q,x,requireFeasibleBinary)
%LEO_EVALUATE_QUADRATIC_SERVICE 评价单个二次服务表达式，不裁剪负下界。
% 接口标注：
% 输入：data：模型；q：aBits/bBits；x：K×M 日程；可选二元校验。
% 输出：result：二次服务 bit 及归一化公平，保留负下界。
% requireFeasibleBinary=false 仅计算多项式值，不提供弦线/误差证书。
if nargin<4, requireFeasibleBinary = true; end
assert(isequal(size(x),data.shape) && all(isfinite(x(:))));
if requireFeasibleBinary
    assert(all(x(:)==0 | x(:)==1));
    assert(all(x(:)<=data.hard.upper) && all(data.hard.A*double(x(:))<=data.hard.rhs));
end
result.resourceBits = zeros(data.shape);
for m = 1:data.shape(2)
    xm = double(x(:,m));
    result.resourceBits(:,m) = xm.*(q.aBits(:,m)-q.bBits(:,:,m)*xm);
end
result = leo_service_totals(data,result.resourceBits,false);
result.nonnegativeQoSFeasible = all(result.userBits>=0);
end
