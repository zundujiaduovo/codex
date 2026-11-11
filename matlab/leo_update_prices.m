function lambdaNext = leo_update_prices(lambda,lowerUserBits,q,sAux,step)
%LEO_UPDATE_PRICES L6/V4：使用价格子问题日程的下界服务，而非恢复/原始服务。
% 接口标注：
% 输入：lambda：价格；lowerUserBits：价格日程下界 bit；q：需求 bit；sAux/step。
% 输出：lambdaNext：非负投影后的新价格，负服务下界不截断。
assert(isequal(size(lambda),size(lowerUserBits),size(q)));
assert(all(isfinite(lambda) & lambda>=0) && all(isfinite(lowerUserBits)));
assert(all(isfinite(q) & q>0) && isscalar(step) && isfinite(step) && step>0);
assert(isscalar(sAux) && isfinite(sAux) && sAux>=0);
lambdaNext = max(0,lambda+step*(sAux-lowerUserBits./q));
end
