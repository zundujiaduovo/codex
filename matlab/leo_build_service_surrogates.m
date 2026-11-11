function proxy = leo_build_service_surrogates(problem,mode,x0,previous)
%LEO_BUILD_SERVICE_SURROGATES 第 7.1-7.5 节：切线下界、弦线上界、二次系数和误差。
% 接口标注：
% 输入：problem：原问题；mode：minimax/zero/current_schedule；x0：仅相切模式需要。
% 输出：proxy：切线/弦线、二次 a/b、合法区间、服务误差 bit 及公平误差界。
% mode='minimax'（默认）、'zero' 或 'current_schedule'；后者需合法参考日程 x0。
if nargin<2, mode = 'minimax'; end
if nargin<3, x0 = []; end
assert(any(strcmp(mode,{'minimax','zero','current_schedule'})));
data = problem.data; K = data.shape(1); T = numel(data.slotToResource);
reuse=nargin>=4 && ~isempty(previous);
if reuse
    assert(isfield(previous,'problemDataSnapshot') && isequaln(previous.problemDataSnapshot,data), ...
        '代理静态缓存只能用于完全相同的模型。');
    proxy=previous;
end
proxy.referenceMode = mode;
proxy.referenceSchedule = x0;
if ~reuse
proxy.limits = leo_interference_limits(data);
proxy.minimaxReferenceW = zeros(K,T);
proxy.chord.alphaBps = zeros(K,T);
proxy.chord.omegaBpsPerW = zeros(K,T);
proxy.rateError.upperMaxBps = zeros(K,T);
proxy.rateError.curvatureGapBoundBps = zeros(K,T);
for t = 1:T
    for i = find(proxy.limits.eventMask(:,t)).'
        chord = leo_chord_upper(data.design.signalW(i,t),data.design.noiseW(i,t), ...
            data.bandwidthHz,0,proxy.limits.maxW(i,t));
        proxy.chord.alphaBps(i,t) = chord.alphaBps;
        proxy.chord.omegaBpsPerW(i,t) = chord.omegaBpsPerW;
        proxy.minimaxReferenceW(i,t) = chord.minimaxReferenceW;
        proxy.rateError.upperMaxBps(i,t) = chord.maxGapBps;
        proxy.rateError.curvatureGapBoundBps(i,t) = chord.curvatureGapBoundBps;
    end
end
end
proxy.referenceW = proxy.minimaxReferenceW;
if strcmp(mode,'current_schedule')
    assert(~isempty(x0),'当前点相切需要显式提供可行 x0。');
    actual = leo_schedule_interference(data,x0);
    for t = 1:T
        m = data.slotToResource(t);
        selected = logical(x0(:,m)) & proxy.limits.eventMask(:,t);
        scale = max(data.design.noiseW(:,t),proxy.limits.maxW(:,t));
        assert(all(actual(selected,t)<=proxy.limits.maxW(selected,t)+1e-12*scale(selected)));
        proxy.referenceW(selected,t) = actual(selected,t);
    end
else
    assert(isempty(x0),'只有 current_schedule 模式接受参考日程。');
    if strcmp(mode,'zero'), proxy.referenceW(:) = 0; end
end
proxy.tangent = leo_tangent_lower(data.design.signalW,data.design.noiseW,data.bandwidthHz,proxy.referenceW);
proxy.tangent.alphaBps(~proxy.limits.eventMask) = 0;
proxy.tangent.omegaBpsPerW(~proxy.limits.eventMask) = 0;
proxy.tangent.rateAtReferenceBps(~proxy.limits.eventMask) = 0;
atZero = leo_rate_and_derivatives(data.design.signalW,data.design.noiseW,data.bandwidthHz,zeros(K,T));
atEnd = leo_rate_and_derivatives(data.design.signalW,data.design.noiseW,data.bandwidthHz,proxy.limits.maxW);
% r-ell 凸，区间最大误差在端点；对任意当前切点也成立。
gapZero = atZero-proxy.tangent.alphaBps;
gapEnd = atEnd-proxy.tangent.alphaBps+proxy.tangent.omegaBpsPerW.*proxy.limits.maxW;
proxy.rateError.lowerMaxBps = max(0,max(gapZero,gapEnd));
proxy.rateError.lowerMaxBps(~proxy.limits.eventMask) = 0;
proxy.lower = leo_assemble_quadratic_service(data,proxy.tangent.alphaBps,proxy.tangent.omegaBpsPerW);
if ~reuse, proxy.upper = leo_assemble_quadratic_service(data,proxy.chord.alphaBps,proxy.chord.omegaBpsPerW); end
[scale,~] = leo_service_adjustment(data);
proxy.error.lowerResourceBits = zeros(data.shape);
proxy.error.upperResourceBits = zeros(data.shape);
for t = 1:T
    m = data.slotToResource(t);
    proxy.error.lowerResourceBits(:,m) = proxy.error.lowerResourceBits(:,m)+ ...
        data.dataDurationS(t)*scale.*proxy.rateError.lowerMaxBps(:,t);
    proxy.error.upperResourceBits(:,m) = proxy.error.upperResourceBits(:,m)+ ...
        data.dataDurationS(t)*scale.*proxy.rateError.upperMaxBps(:,t);
end
proxy.error.lowerUserBits = sum(proxy.error.lowerResourceBits,2);
proxy.error.upperUserBits = sum(proxy.error.upperResourceBits,2);
proxy.error.optimalFairnessGapBound = max(proxy.error.lowerUserBits./data.qosTargetBits);
if ~leo_is_lexicographic(data), proxy.error.optimalFairnessGapBound=min(1,proxy.error.optimalFairnessGapBound); end
proxy.scope = 'Service bounds only on feasible binary schedules; E3 fairness gap is for baseline O2 optima.';
proxy.problemDataSnapshot=data;
proxy.referenceTouchMaxAbsBits = NaN;
if strcmp(mode,'current_schedule')
    original = problem.evaluate(x0);
    lower = leo_evaluate_quadratic_service(data,proxy.lower,x0);
    proxy.referenceTouchMaxAbsBits = max(abs(original.signedUserBits-lower.userBits));
    assert(all(abs(original.signedUserBits-lower.userBits)<=1e-10*max(1,abs(original.signedUserBits))));
end
end
