function [lambdaNext,state] = leo_update_prices(lambda,lowerUserBits,q,sAux,step,phase,options,state)
%LEO_UPDATE_PRICES L6/V4：使用价格子问题日程的下界服务，而非恢复/原始服务。
% 接口标注：
% 输入：lambda：价格；lowerUserBits：价格日程下界 bit；q：需求 bit；sAux/step。
% 输出：lambdaNext：非负投影后的新价格，负服务下界不截断。
assert(isequal(size(lambda),size(lowerUserBits),size(q)));
assert(all(isfinite(lambda) & lambda>=0) && all(isfinite(lowerUserBits)));
assert(all(isfinite(q) & q>0) && isscalar(step) && isfinite(step) && step>0);
assert(isscalar(sAux) && isfinite(sAux) && sAux>=0);
if nargin<6, phase='legacy'; end
if nargin<7, options=struct(); end
if nargin<8, state=struct(); end
if strcmp(phase,'fairness') && isfield(options,'coordination') && options.coordination.normalizedFairness
    c=options.coordination; ratios=lowerUserBits./q;
    if ~isfield(state,'smoothedRatios'), state.smoothedRatios=ratios;
    else, state.smoothedRatios=(1-c.priceSmoothing)*state.smoothedRatios+c.priceSmoothing*ratios; end
    % Mirror descent minimizes weighted attained ORIGINAL service over the simplex.
    relative=mean(state.smoothedRatios)-state.smoothedRatios;
    relative=relative/max(1,max(abs(relative)));
    logWeight=log(max(lambda,c.priceFloor/numel(lambda)))+step*relative;
    logWeight=logWeight-max(logWeight); proposal=exp(logWeight); proposal=proposal/sum(proposal);
    lambdaNext=(1-c.priceMix)*lambda+c.priceMix*proposal;
    lambdaNext=max(lambdaNext,c.priceFloor/numel(lambda)); lambdaNext=lambdaNext/sum(lambdaNext);
    return;
end
lambdaNext = max(0,lambda+step*(sAux-lowerUserBits./q));
end
