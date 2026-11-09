function o = leo_benchmark_options(overrides)
%LEO_BENCHMARK_OPTIONS 第 13.3 节统一实验设置：同输入、同种子、同端到端时间上限。
% 输入：可选覆盖结构；输出：方法列表、重复种子、预算及结果目录等实验参数。
o.methods = {'initial','original_greedy','original_exchange','original_tabu', ...
    'price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local','price_local_adaptive','price_miqp','proxy_milp', ...
    'sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
% 默认固定一个复查种子；显式提供 seeds 时使用指定值。
if nargin>0 && isfield(overrides,'seeds'), o.seeds = overrides.seeds;
else, o.seeds = 71669974; end
o.budgetSeconds = 12;              % 演示预算；正式规模实验可统一提高到 60 s 等
o.outputDirectory = '';
o.exhaustive = true;
o.makePlots = true;
o.verbose = true;
o.method = leo_method_options(struct('verbose',false));
if nargin>0
    assert(isstruct(overrides) && isscalar(overrides));
    names = fieldnames(overrides);
    for j = 1:numel(names)
        assert(isfield(o,names{j}),['未知对比参数: ',names{j}]); o.(names{j}) = overrides.(names{j});
    end
end
valid = {'initial','original_greedy','original_exchange','original_tabu','price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local','price_local_adaptive', ...
    'price_miqp','proxy_milp','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
assert(iscell(o.methods) && ~isempty(o.methods) && all(ismember(o.methods,valid)) && numel(unique(o.methods))==numel(o.methods));
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds) && ...
    all(isfinite(o.seeds) & o.seeds>=0 & o.seeds==fix(o.seeds) & o.seeds<=2^32-1));
assert(isscalar(o.budgetSeconds) && isfinite(o.budgetSeconds) && o.budgetSeconds>0);
assert(ischar(o.outputDirectory));
for f = {'exhaustive','makePlots','verbose'}
    v = o.(f{1}); assert(isscalar(v) && (v==0 || v==1)); o.(f{1}) = logical(v);
end
o.method = leo_method_options(o.method);
end
