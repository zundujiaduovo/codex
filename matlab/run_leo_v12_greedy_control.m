function [report,files] = run_leo_v12_greedy_control(directory,overrides,render)
%RUN_LEO_V12_GREEDY_CONTROL 给已有三方法实验补原式贪婪，仅执行缺失的贪婪运行。
% 原三方法的配对文件、日程、成绩和证书均保留；四方法另存greedy_control目录。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, overrides=struct(); end
if nargin<3, render=true; end
loaded=load(fullfile(directory,'experiment.mat'),'experiment'); e=loaded.experiment;
assert(strcmp(e.version,'V12 uncapped lexicographic') && leo_is_lexicographic(e.problemData));
base=leo_v12_load_report(directory); o=struct('budgetSeconds',e.protocol.budgetSeconds);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
assert(isscalar(o.budgetSeconds) && isfinite(o.budgetSeconds) && o.budgetSeconds>0);
out=fullfile(directory,'greedy_control'); if ~exist(out,'dir'), mkdir(out); end
protocol=struct('version','V12 greedy supplement 1','baseProtocol',e.protocol,'options',o);
report=base;
for seed=e.protocol.seeds
    path=fullfile(out,sprintf('greedy_seed_%.0f.mat',seed));
    if exist(path,'file')==2
        loaded=load(path,'control','savedProtocol'); assert(isequaln(loaded.savedProtocol,protocol),'Greedy control protocol changed; use another experiment directory.');
        control=loaded.control; fprintf('V12 greedy seed %.0f retained.\n',seed);
    else
        model=e.modelSnapshot;
        model.problem=leo_form_problem(model.parameters,model.resources,model.beams,model.design);
        assert(isequaln(model.problem.data,e.problemData));
        b=struct('methods',{{'original_greedy'}},'seeds',seed,'budgetSeconds',o.budgetSeconds, ...
            'method',e.protocol.method,'exhaustive',false,'makePlots',false,'diagnosticSurrogates',false, ...
            'outputDirectory','','verbose',true);
        control=leo_benchmark_case(model,b);
        assert(strcmp(control.records.status,'completed'),control.records.message);
        at=find([base.records.seed]==seed & strcmp({base.records.status},'completed'),1); assert(~isempty(at));
        assert(isequal(control.solutions{1}.initial.x,base.solutions{at}.initial.x),'Greedy did not receive the same initial schedule.');
        savedProtocol=protocol; temporary=[tempname(out),'.mat']; save(temporary,'control','savedProtocol','-v7');
        [ok,message]=movefile(temporary,path); assert(ok,message);
    end
    solution=control.solutions{1}; exact=leo_evaluate_service(e.problemData,solution.x);
    assert(all(exact.demandRatio>=solution.stage1.service.fairness));
    assert(exact.totalBits>=solution.stage1.service.totalBits);
    row=control.records; row.globalFairnessUpper=base.fairnessCertificate.upper;
    assert(row.fairness<=row.globalFairnessUpper+1e-9);
    row.fairnessGapAtLeast=max(0,base.fairnessCertificate.lower-row.fairness);
    row.fairnessGapAtMost=max(0,row.globalFairnessUpper-row.fairness);
    row.stage1CertificateConfirmed=row.globalFairnessUpper-row.stage1Fairness<=max(base.fairnessCertificate.options.absoluteGap,base.fairnessCertificate.options.relativeGap*row.globalFairnessUpper);
    row.conditionalThroughputUpperBits=NaN;
    row.sampleMeanTotalBits=NaN; row.sampleJointSuccessRate=NaN; row.sampleJointFailure95Upper=NaN;
    row.jainFairness=NaN; if any(exact.userBits), row.jainFairness=sum(exact.userBits)^2/(numel(exact.userBits)*sum(exact.userBits.^2)); end
    % 对齐旧版本可能新增/缺失的报告列；缺失数据不伪填为零。
    names=union(fieldnames(report.records),fieldnames(row));
    for k=1:numel(names)
        name=names{k};
        if ~isfield(report.records,name), [report.records.(name)]=deal(missing(row.(name))); end
        if ~isfield(row,name), row.(name)=missing(report.records(1).(name)); end
    end
    report.records(end+1,1)=orderfields(row,report.records); report.solutions{end+1,1}=solution;
end
report.options.methods=[base.options.methods,{'original_greedy'}]; report.options.outputDirectory=out;
report.options.diagnosticSurrogates=false; report.caseName='v12_with_original_greedy';
report.summary=leo_summarize_benchmark(report.records,report.options.methods);
report.greedyControlProtocol=protocol; leo_export_benchmark(report,out);
primaryUsers=struct([]); primarySchedules=struct([]);
for j=1:numel(report.records)
    row=report.records(j); if ~strcmp(row.status,'completed'), continue; end
    solution=report.solutions{j}; primary=leo_evaluate_service(e.problemData,solution.stage1.x);
    for i=1:e.problemData.shape(1)
        entry=struct('method',row.method,'seed',row.seed,'user',i,'targetBits',e.problemData.qosTargetBits(i), ...
            'serviceBits',primary.userBits(i),'demandRatio',primary.demandRatio(i));
        primaryUsers=leo_append_struct(primaryUsers,entry);
        for m=1:e.problemData.shape(2)
            entry=struct('method',row.method,'seed',row.seed,'user',i,'resource',m, ...
                'selected',solution.stage1.x(i,m),'beam',e.problemData.beamIndex(i,m));
            primarySchedules=leo_append_struct(primarySchedules,entry);
        end
    end
end
leo_write_struct_csv(fullfile(out,'stage1_user_service.csv'),primaryUsers);
leo_write_struct_csv(fullfile(out,'stage1_schedules.csv'),primarySchedules);
for name={'original_model.mat','fairness_certificate_summary.csv','fairness_certificate_schedule.csv','fairness_certificate_users.csv'}
    source=fullfile(directory,name{1});
    if exist(source,'file')==2, [ok,message]=copyfile(source,fullfile(out,name{1})); assert(ok,message); end
end
specs=leo_build_v12_specs(report,leo_v12_trace_data(report));
fid=fopen(fullfile(out,'v12_specs.json'),'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
files={}; if render, files=leo_render_plot_specs(specs,out); end
[~,more]=run_leo_v12_diagnostics(report,out,render); files=[files,more];
fprintf('V12 four-method supplement saved: %s. Original three methods were not re-run.\n',out);
end
function value=missing(example)
value=NaN; if ischar(example), value=''; end
end
