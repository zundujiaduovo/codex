function report = leo_check_surrogate_groups(problem,proxy,maxGroupsPerResource)
%LEO_CHECK_SURROGATE_GROUPS 枚举各资源全部合法组，检查每用户的服务夹逼和误差。
% 接口标注：
% 输入：problem/proxy：原模型及代理；maxGroupsPerResource：枚举保护上限。
% 输出：report：各资源全部合法组的夹逼/误差检查及覆盖组合规模。
% 服务跨资源可加，因此各资源全组通过即覆盖其笛卡尔积中的所有完整日程。
% 不声称直接遍历了完整日程；大规模需显式限额。
if nargin<3, maxGroupsPerResource = 1e4; end
data = problem.data; K = data.shape(1); M = data.shape(2);
estimate = leo_exhaustive_size(data);
assert(all(estimate.groupsPerResource<=maxGroupsPerResource),'合法组数超过本检查限额。');
report.groupsChecked = 0;
report.maxLowerViolationBits = 0;
report.maxUpperViolationBits = 0;
report.maxErrorBudgetViolationBits = 0;
report.maxLowerGapBits = 0;
report.maxUpperGapBits = 0;
for m = 1:M
    groups = leo_enumerate_resource_groups(data,m,maxGroupsPerResource);
    actual = leo_resource_group_services(data,m,groups);
    X = double(groups);
    lower = X.*bsxfun(@minus,proxy.lower.aBits(:,m),proxy.lower.bBits(:,:,m)*X);
    upper = X.*bsxfun(@minus,proxy.upper.aBits(:,m),proxy.upper.bBits(:,:,m)*X);
    lowerBudget = bsxfun(@times,proxy.error.lowerResourceBits(:,m),X);
    upperBudget = bsxfun(@times,proxy.error.upperResourceBits(:,m),X);
    tolerance = 1e-10*max(1,abs(actual));
    valid = lower<=actual+tolerance; assert(all(valid(:)));
    valid = actual<=upper+tolerance; assert(all(valid(:)));
    valid = actual-lower<=lowerBudget+tolerance; assert(all(valid(:)));
    valid = upper-actual<=upperBudget+tolerance; assert(all(valid(:)));
    report.maxLowerViolationBits = max(report.maxLowerViolationBits,max(lower(:)-actual(:)));
    report.maxUpperViolationBits = max(report.maxUpperViolationBits,max(actual(:)-upper(:)));
    report.maxErrorBudgetViolationBits = max([report.maxErrorBudgetViolationBits; ...
        actual(:)-lower(:)-lowerBudget(:);upper(:)-actual(:)-upperBudget(:)]);
    report.maxLowerGapBits = max(report.maxLowerGapBits,max(actual(:)-lower(:)));
    report.maxUpperGapBits = max(report.maxUpperGapBits,max(upper(:)-actual(:)));
    report.groupsChecked = report.groupsChecked+size(groups,2);
end
report.resourcesChecked = M;
report.allGroupsPassed = true;
report.coveredFullScheduleLog10 = estimate.log10Schedules;
report.scope = 'All feasible per-resource groups checked; full schedules covered by additivity.';
assert(K>=1 && report.groupsChecked>=M);
end
