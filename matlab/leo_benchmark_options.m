function o = leo_benchmark_options(overrides,data)
%LEO_BENCHMARK_OPTIONS 第 13.3 节统一实验设置：同输入、同种子、同端到端时间上限。
% 输入：可选覆盖结构、可选原模型data；输出：方法/种子/预算；默认引擎随data目标选择。
o.methods = {'initial','original_exchange','original_tabu','original_tabu_independent', ...
    'sb_v8_blockwise','local_v8_blockwise','price_local_blockwise','price_local_joint'};
% 有原模型时默认方法随目标选择；历史无模型调用保留V10/V11列表。
if nargin>=2 && leo_is_lexicographic(data) && (nargin<1 || ~isfield(overrides,'methods'))
    o.methods(strcmp(o.methods,'sb_v8_blockwise'))={'sb_v12_lexicographic'};
    o.methods(strcmp(o.methods,'local_v8_blockwise'))={'local_v12_lexicographic'};
end
% 默认固定一个复查种子；显式提供 seeds 时使用指定值。
if nargin>0 && isfield(overrides,'seeds'), o.seeds = overrides.seeds;
else, o.seeds = 71669974; end
o.budgetSeconds = 120;
o.outputDirectory = '';
o.exhaustive = true;
o.makePlots = true;
o.verbose = true;
o.diagnosticSurrogates = true;      % 默认主比较关闭事后代理诊断；旧详细图可启用
o.method = leo_method_options(struct('verbose',false,'fairnessRounds',10000,'throughputRounds',10000));
if nargin>0
    assert(isstruct(overrides) && isscalar(overrides));
    names = fieldnames(overrides);
    for j = 1:numel(names)
        assert(isfield(o,names{j}),['未知对比参数: ',names{j}]); o.(names{j}) = overrides.(names{j});
    end
end
valid = {'initial','original_greedy','original_exchange','original_tabu','original_tabu_independent', ...
    'Tabu','SB','Local','Proxy+Tabu','proxy_tabu','Greedy', ...
    'sb_v12_lexicographic','local_v12_lexicographic', ...
    'sb_v8_blockwise','local_v8_blockwise', ...
    'price_local_blockwise','price_sb_joint','price_local_joint','price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local','price_local_adaptive', ...
    'price_miqp','proxy_milp','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio'};
assert(iscell(o.methods) && ~isempty(o.methods) && all(ismember(o.methods,valid)) && numel(unique(o.methods))==numel(o.methods));
assert(isnumeric(o.seeds) && isvector(o.seeds) && ~isempty(o.seeds) && ...
    all(isfinite(o.seeds) & o.seeds>=0 & o.seeds==fix(o.seeds) & o.seeds<=2^32-1));
assert(isscalar(o.budgetSeconds) && o.budgetSeconds>0 && ...
    (isfinite(o.budgetSeconds) || (isinf(o.budgetSeconds) && leo_iteration_only(o.method))));
assert(ischar(o.outputDirectory));
if isfield(o.method,'stopping'), o.method=leo_method_options(o.method); end
for f = {'exhaustive','makePlots','verbose','diagnosticSurrogates'}
    v = o.(f{1}); assert(isscalar(v) && (v==0 || v==1)); o.(f{1}) = logical(v);
end
o.method = leo_method_options(o.method);
end
