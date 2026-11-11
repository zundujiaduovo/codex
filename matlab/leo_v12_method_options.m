function o = leo_v12_method_options(overrides)
%LEO_V12_METHOD_OPTIONS 冻结内层参数外增加可选停止设置，不修改V8历史文件。
if nargin<1, overrides=struct(); end
[overrides,iterationFields]=leo_extract_iteration_options(overrides);
proxyTabu=isfield(overrides,'innerSolver') && strcmp(overrides.innerSolver,'tabu');
if proxyTabu, overrides.innerSolver='local'; end
hasStopping=isfield(overrides,'stopping');
if hasStopping, stop=leo_stopping_options(overrides.stopping); overrides=rmfield(overrides,'stopping'); end
hasAudit=isfield(overrides,'audit');
if hasAudit, audit=leo_audit_options(overrides.audit); overrides=rmfield(overrides,'audit'); end
hasFast=isfield(overrides,'fastPolish');
if hasFast, fast=overrides.fastPolish; assert(isscalar(fast) && any(fast==[0,1])); overrides=rmfield(overrides,'fastPolish'); end
o=leo_v8_method_options(overrides);
if hasStopping, o.stopping=stop; end
if hasAudit, o.audit=audit; end
if hasFast, o.fastPolish=logical(fast); end
if proxyTabu, o.innerSolver='tabu'; end
names=fieldnames(iterationFields);
for j=1:numel(names), o.(names{j})=iterationFields.(names{j}); end
end
