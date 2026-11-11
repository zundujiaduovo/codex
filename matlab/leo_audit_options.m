function o = leo_audit_options(overrides)
%LEO_AUDIT_OPTIONS 只记录有限见证；事后诊断不参与方法搜索。
o=struct('enabled',false,'snapshots',4,'tabuMoves',16);
if nargin>0
    names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
    for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
end
assert(isscalar(o.enabled) && any(o.enabled==[0,1])); o.enabled=logical(o.enabled);
assert(all([o.snapshots,o.tabuMoves]>=1) && all([o.snapshots,o.tabuMoves]==fix([o.snapshots,o.tabuMoves])));
end
