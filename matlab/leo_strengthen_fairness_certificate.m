function certificate = leo_strengthen_fairness_certificate(report,certificate,seconds,iterations)
%LEO_STRENGTHEN_FAIRNESS_CERTIFICATE 合并已有有效界与配置LP对偶界，保留原下界日程。
if nargin<3, seconds=30; end
if nargin<4, iterations=150; end
assert(isequaln(certificate.problemDataSnapshot,report.problemData));
report.fairnessCertificate=certificate;
bound=leo_cardinality_fairness_bound(report,struct('maxSeconds',seconds,'maxIterations',iterations));
certificate.coarseUpper=leo_fairness_limit(report.problemData);
certificate.cardinalityRelaxation=bound;
previousUpper=certificate.upper;
certificate.upper=min(certificate.upper,bound.upper);
assert(certificate.upper>=certificate.lower-1e-8*max(1,certificate.upper));
certificate.absoluteGap=max(0,certificate.upper-certificate.lower);
certificate.relativeGap=certificate.absoluteGap/max(certificate.upper,eps);
o=certificate.options;
certificate.gapTargetMet=certificate.absoluteGap<=max(o.absoluteGap,o.relativeGap*max(certificate.upper,eps));
certificate.boundSchemaVersion=2;
certificate.upperBoundKind=bound.kind;
if previousUpper<bound.upper, certificate.upperBoundKind='Previous matching original-model certificate'; end
end
