function result = leo_theory_bound(report,options)
%LEO_THEORY_BOUND 全用户 QoS 达标时，保证总服务的可行下界与全域上界。
% 精确定价枚举每块全部合法波束子集，投影次梯度只选择对偶价格；
% 未枚举完或超出规模时退回 UB1 基数放松，任何阶段均不把候选池上界当成全域上界。
% 单位 bit/周期。上界使用双精度和小量向上裕量，不是区间算术证明。
if nargin<2, options = struct(); end
if ~isfield(options,'maxSeconds'), options.maxSeconds = 45; end
if ~isfield(options,'maxIterations'), options.maxIterations = 40; end
if ~isfield(options,'maxBeams'), options.maxBeams = 18; end
if ~isfield(options,'maxSubsets'), options.maxSubsets = 200000; end
if ~isfield(options,'maxTotalSubsets'), options.maxTotalSubsets = 1500000; end
data = report.problemData; K = data.shape(1); M = data.shape(2);
[scale,margin] = leo_service_adjustment(data);
q = data.qosTargetBits(:)/1e6; marginM = margin(:)/1e6;
result.fairnessFloor = 1; result.userTargetsBits = data.qosTargetBits;
result.lowerBits = NaN; result.bestMethod = ''; result.bestSeed = NaN;
result.recordServiceBits = NaN(numel(report.records),1);
result.recordFeasible = false(numel(report.records),1);
for j = 1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed') || isempty(report.solutions{j}), continue; end
    s = leo_evaluate_service(data,report.solutions{j}.x);
    result.recordServiceBits(j) = s.totalBits;
    result.recordFeasible(j) = all(s.userBits>=data.qosTargetBits);
    if result.recordFeasible(j) && (isnan(result.lowerBits) || s.totalBits>result.lowerBits)
        result.lowerBits = s.totalBits; result.bestMethod = report.records(j).method;
        result.bestSeed = report.records(j).seed;
    end
end
started = tic; lambda = zeros(K,1); proxyCache = leo_prepare_upper_bounds(data);
coarse = leo_original_upper_bound(data,proxyCache,lambda,'throughput',1);
upperM = coarse.value*data.referenceBits/1e6;
result.kind = 'UB1 cardinality relaxation'; result.pricingComplete = false;
result.pricingIterations = 0; result.subsetCounts = zeros(1,M);
result.pricingStatus = '';
result.iterationTrace=struct([]); result.blockTrace=struct([]);
% 枚举时守住规模与预算；任何未完成块都不能用于完整定价上界。
blocks = cell(1,M); canEnumerate = true;
for m = 1:M
    if toc(started)>=options.maxSeconds, result.pricingStatus = 'time limit during enumeration'; canEnumerate = false; break; end
    ids = find(data.available(:,m)); beams = unique(data.beamIndex(ids,m)); B = numel(beams);
    if B>options.maxBeams, result.pricingStatus = 'beam count exceeds exact pricing limit'; canEnumerate = false; break; end
    count = 0;
    for n = 0:min(B,data.maxStreams), count = count+nchoosek(B,n); end
    if count>options.maxSubsets, result.pricingStatus = 'subset count exceeds exact pricing limit'; canEnumerate = false; break; end
    if sum(result.subsetCounts)+count>options.maxTotalSubsets
        result.pricingStatus = 'total subset count exceeds memory limit'; canEnumerate = false; break;
    end
    masks = uint32((0:2^B-1).'); chosen = false(numel(masks),B);
    for b = 1:B, chosen(:,b) = logical(bitget(masks,b)); end
    chosen = chosen(sum(chosen,2)<=data.maxStreams,:); count = size(chosen,1);
    result.subsetCounts(m) = count;
    local = zeros(K,1);
    for b = 1:B, local(ids(data.beamIndex(ids,m)==beams(b))) = b; end
    rates = zeros(K,count);
    for t = find(data.slotToResource==m & data.dataDurationS>0)
        C = data.design.beamPowerW(:,beams,t);
        for i = ids.', C(i,local(i)) = 0; end
        interference = C*double(chosen.');
        denom = bsxfun(@plus,data.design.noiseW(:,t),interference);
        sinr = bsxfun(@rdivide,data.design.signalW(:,t),denom);
        rates = rates+data.dataDurationS(t)*data.bandwidthHz/log(2)*log1p(sinr)/1e6;
    end
    rates = bsxfun(@times,scale,rates);
    rates(~data.available(:,m),:) = 0;
    for i = ids.', rates(i,:) = rates(i,:).*double(chosen(:,local(i)).'); end
    blockRow=struct('resource',m,'availableUsers',numel(ids),'availableBeams',B,'subsets',count);
    if isempty(result.blockTrace), result.blockTrace=blockRow; else, result.blockTrace(end+1,1)=blockRow; end
    blocks{m} = struct('beams',beams,'chosen',chosen,'rates',rates);
    fprintf('Theory pricing: block %d/%d, %d beams, %d subsets\n',m,M,B,count);
end
if canEnumerate
    result.pricingComplete = true;
    bestKind = result.kind; bestM = upperM; bestLambda = lambda;
    for k = 1:options.maxIterations
        if k>1 && toc(started)>=options.maxSeconds, break; end
        [support,service] = exact_support(data,blocks,1+lambda);
        candidateM = support-lambda.'*(q+marginM)-sum(marginM);
        % 浮点裕量向上，不将数值舍入当作精确数学证书。
        candidateM = candidateM+1e-9*max(1,abs(candidateM));
        if candidateM<bestM
            bestM = candidateM; bestLambda = lambda;
            bestKind = 'Full beam-subset pricing with Lagrangian dual';
        end
        result.pricingIterations = k;
        traceRow=struct('iteration',k,'candidateUpperBits',candidateM*1e6, ...
            'bestUpperBits',bestM*1e6,'knownFeasibleLowerBits',result.lowerBits, ...
            'lambdaL2',norm(lambda),'gradientNorm',NaN,'stepSize',NaN);
        if isempty(result.iterationTrace), result.iterationTrace=traceRow; else, result.iterationTrace(end+1,1)=traceRow; end
        if isnan(result.lowerBits), break; end
        lowerM = result.lowerBits/1e6;
        if candidateM<lowerM-1e-6*max(1,abs(lowerM))
            error('leo:upperBoundInvalid','Theory upper bound is below an independently checked feasible schedule.');
        end
        gradient = service-(q+marginM);
        norm2 = sum(gradient.^2);
        if norm2<1e-16 || candidateM-lowerM<1e-8, break; end
        step = .8*max(0,candidateM-lowerM)/norm2;
        result.iterationTrace(end).gradientNorm=sqrt(norm2); result.iterationTrace(end).stepSize=step;
        lambda = max(0,lambda-step*gradient);
    end
    upperM = bestM; result.lambda = bestLambda; result.kind = bestKind;
    result.pricingStatus = 'all legal beam subsets priced; upper bound need not be attainable';
else
    result.lambda = zeros(K,1);
end
if ~isnan(result.lowerBits) && upperM*1e6<result.lowerBits-1e-6*max(1,result.lowerBits)
    error('leo:upperBoundInvalid','Upper bound is below feasible lower bound.');
end
result.upperBits = max(upperM*1e6,0)+1e-9*max(1,abs(upperM*1e6));
if ~isnan(result.lowerBits), result.upperBits = max(result.upperBits,result.lowerBits); end
result.elapsedSeconds = toc(started);
result.scope = 'Full-user QoS floor 1; certified-service model; bound is not stochastic physical capacity.';
end

function [total,userService] = exact_support(data,blocks,w)
K = data.shape(1); total = 0; userService = zeros(K,1);
for m = 1:data.shape(2)
    block = blocks{m}; scores = zeros(1,size(block.rates,2));
    for b = 1:numel(block.beams)
        ids = find(data.available(:,m) & data.beamIndex(:,m)==block.beams(b));
        scores = scores+max(bsxfun(@times,w(ids),block.rates(ids,:)),[],1);
    end
    [value,choice] = max(scores); total = total+value;
    for b = find(block.chosen(choice,:))
        ids = find(data.available(:,m) & data.beamIndex(:,m)==block.beams(b));
        [~,best] = max(w(ids).*block.rates(ids,choice));
        i = ids(best); userService(i) = userService(i)+block.rates(i,choice);
    end
end
end
