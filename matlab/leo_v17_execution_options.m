function p=leo_v17_execution_options(overrides)
% The trajectory count is independent of CPU worker count or GPU device count.
p=struct('backend','cpu','deviceIndex',1,'precision','single');
if nargin<1, overrides=struct(); end
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(p))));
for j=1:numel(names), p.(names{j})=overrides.(names{j}); end
assert(ischar(p.backend) && any(strcmp(p.backend,{'cpu','gpu'})));
assert(ischar(p.precision) && any(strcmp(p.precision,{'single','double'})));
assert(isscalar(p.deviceIndex) && isfinite(p.deviceIndex) && p.deviceIndex>=1 && p.deviceIndex==fix(p.deviceIndex));
end
