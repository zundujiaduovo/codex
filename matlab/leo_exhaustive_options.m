function options = leo_exhaustive_options(overrides)
%LEO_EXHAUSTIVE_OPTIONS 穷举保护参数；超限明确返回，不缩小原问题或抽样。
% 接口标注：
% 输入：overrides：可选规模、内存、批次及时间上限。
% 输出：options：完整穷举的保护配置，不自动缩小物理问题。
options.enabled = false;             % 主函数保持建模默认；对照入口开启
options.maxSchedules = 2e7;          % 允许完整穷举的最大日程数
options.maxGroupsPerResource = 1e5;
options.maxMemoryBytes = 256*1024^2;  % 缓存/批处理工作区的估算上限
options.batchSize = 65536;
options.maxSeconds = 120;            % 包括组服务预计算；每阶段/批次检查
options.verbose = true;
if nargin>0 && ~isempty(overrides)
    assert(isstruct(overrides) && isscalar(overrides));
    names = fieldnames(overrides);
    for k = 1:numel(names)
        assert(isfield(options,names{k}),['未知穷举选项: ',names{k}]);
        options.(names{k}) = overrides.(names{k});
    end
end
limits = [options.maxSchedules,options.maxGroupsPerResource,options.batchSize];
assert(all(isfinite(limits)) && all(limits>=1) && all(limits==fix(limits)) && ...
    all(limits<=flintmax/2),'计数/批次上限必须是可精确表示的正整数。');
assert(isscalar(options.maxMemoryBytes) && isfinite(options.maxMemoryBytes) && options.maxMemoryBytes>0);
assert(isscalar(options.maxSeconds) && isfinite(options.maxSeconds) && options.maxSeconds>=0);
assert(isscalar(options.enabled) && any(options.enabled==[0,1]));
assert(isscalar(options.verbose) && any(options.verbose==[0,1]));
end
