function [diagnosis,files] = run_leo_v13_diagnose(directory,overrides,render)
%RUN_LEO_V13_DIAGNOSE 既有方法结果只读；新界、诊断和重画结果写入独立子目录。
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
o=struct('boundSeconds',60,'boundIterations',300,'candidateOptions',struct());
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
report=leo_v12_load_report(directory); assert(strcmp(report.releaseTag,'V13'));
original=report.records; c=report.fairnessCertificate;
c=leo_strengthen_fairness_certificate(report,c,o.boundSeconds,o.boundIterations);
report.fairnessCertificate=c;
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    report.records(j).globalFairnessUpper=c.upper;
    report.records(j).fairnessGapAtLeast=max(0,c.lower-r.fairness);
    report.records(j).fairnessGapAtMost=max(0,c.upper-r.fairness);
    report.records(j).stage1CertificateConfirmed=c.upper-r.stage1Fairness<=max(c.options.absoluteGap,c.options.relativeGap*c.upper);
    assert(report.records(j).fairness==original(j).fairness && report.records(j).totalBits==original(j).totalBits);
end
out=fullfile(directory,'diagnosis'); if ~exist(out,'dir'), mkdir(out); end
save(fullfile(out,'benchmark.mat'),'report','-v7');
bound=c.cardinalityRelaxation;
leo_write_struct_csv(fullfile(out,'fairness_bound_components.csv'), ...
    struct('coarseUpper',c.coarseUpper,'uniformCardinalityUpper',bound.uniformUpper, ...
    'configurationLPUpper',bound.upper,'mergedGlobalUpper',c.upper, ...
    'lpConverged',bound.lpConverged,'lpValue',bound.lpValue,'status',bound.status));
leo_write_struct_csv(fullfile(out,'fairness_bound_trace.csv'),bound.trace);
files=run_leo_v13_replot(out,render);
candidate=o.candidateOptions; candidate.outputDirectory=fullfile(out,'candidate_audit');
[audit,auditFiles]=run_leo_v13_candidate_audit(report,candidate,render); files=[files,auditFiles];
diagnosis=struct('certificate',c,'candidateAudit',audit,'sourceDirectory',directory,'outputDirectory',out);
save(fullfile(out,'diagnosis.mat'),'diagnosis','-v7');
fprintf('Fairness upper: no-interference %.9g -> uniform cardinality %.9g -> configuration LP dual %.9g; LP status %s.\n', ...
    c.coarseUpper,bound.uniformUpper,c.upper,bound.status);
fprintf('Original method scores, schedules and source benchmark unchanged. Diagnosis: %s\n',out);
end
