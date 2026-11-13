function [lower,diagnosis]=leo_v17_calibrate_tangent(d,proxy,m,w,ctx,groups)
% Select valid tangents using a frozen candidate set, not a fitted unconstrained Q.
% Convex rate-vs-interference tangents remain global lower bounds at every cut.
[~,keep]=unique([ctx.group,groups].','rows','stable'); allGroups=[ctx.group,groups]; allGroups=allGroups(:,keep);
bits=leo_resource_group_services(d,m,allGroups);
actual=w.'*bsxfun(@minus,bits,ctx.service.resourceBits(:,m));
lower=proxy.lower; best=measure(lower); before=best.normalizedRmsError;
[~,worst]=max(abs(best.actual-best.predicted)); anchor=allGroups(:,worst);
trials=0;
for fraction=[0,.25,.5,.75,1]
    reference=(1-fraction)*double(ctx.group)+fraction*double(anchor);
    candidate=leo_v13_touch_resource(d,proxy,m,reference); audit=measure(candidate); trials=trials+1;
    % Never trade more sign reversals for a smaller pointwise error.
    if audit.signReversals<=best.signReversals && audit.normalizedRmsError<best.normalizedRmsError
        lower=candidate; best=audit;
    end
end
diagnosis=struct('before',before,'after',best.normalizedRmsError,'signReversals',best.signReversals, ...
    'evaluations',size(allGroups,2),'tangentsTried',trials,'scope','Frozen-pool gain calibration, not a global approximation guarantee.');
    function audit=measure(line)
        x=double(allGroups); base=double(ctx.group);
        value=w.'*(x.*bsxfun(@minus,line.aBits(:,m),line.bBits(:,:,m)*x));
        center=w.'*(base.*(line.aBits(:,m)-line.bBits(:,:,m)*base));
        audit=leo_v17_gain_audit(actual,value-center,1e-7);
    end
end
