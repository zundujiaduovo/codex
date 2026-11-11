function report = run_leo_v12_pair(directory,seed)
%RUN_LEO_V12_PAIR 执行或读取一个完整配对；同模型、同种子、同初态、同时间。
saved=load(fullfile(directory,'experiment.mat'),'experiment'); e=saved.experiment; o=e.protocol;
assert(strcmp(e.version,'V12 uncapped lexicographic') && leo_is_lexicographic(e.problemData),'Cannot mix V10/V11 runs with the V12 objective.');
index=find(o.seeds==seed); assert(isscalar(index),'Seed is not in the saved experiment protocol.');
pairDir=fullfile(directory,'pairs'); if ~exist(pairDir,'dir'), mkdir(pairDir); end
path=fullfile(pairDir,sprintf('seed_%.0f.mat',seed));
if exist(path,'file')
    saved=load(path,'report'); report=saved.report;
    assert(isequaln(report.pairedProtocol,o) && isequaln(report.problemData,e.problemData),'Saved pair does not match experiment.');
    fprintf('V12 pair %.0f already saved; retained.\n',seed); return;
end
model=e.modelSnapshot;
model.problem=leo_form_problem(model.parameters,model.resources,model.beams,model.design);
assert(isequaln(model.problem.data,e.problemData));
% 循环轮换执行顺序，避免SB总在热机后运行；每个方法重置为同一搜索种子。
order=mod((0:2)+index-1,3)+1;
b=struct('methods',{e.methods(order)},'seeds',seed,'budgetSeconds',o.budgetSeconds, ...
    'outputDirectory','','exhaustive',false,'makePlots',false,'verbose',true, ...
    'diagnosticSurrogates',false,'method',o.method);
report=leo_benchmark_case(model,b);
report.caseName='v12_uncapped_lexicographic'; report.pairedProtocol=o;
report.sceneSeed=o.sceneSeed; report.validationSeed=o.validationSeed; report.validationSamples=o.validationSamples;
first=[];
for j=1:numel(report.records)
    row=report.records(j); report.records(j).sampleMeanTotalBits=NaN;
    report.records(j).sampleJointSuccessRate=NaN; report.records(j).sampleJointFailure95Upper=NaN;
    report.records(j).jainFairness=NaN;
    if ~strcmp(row.status,'completed'), continue; end
    result=report.solutions{j}; exact=leo_evaluate_service(e.problemData,result.x);
    assert(abs(exact.totalBits-row.totalBits)<=1e-8*max(1,abs(row.totalBits)));
    if isempty(first), first=result.initial.x;
    else, assert(isequal(first,result.initial.x),'Paired methods did not receive the same initial schedule.'); end
    bits=exact.userBits;
    if any(bits), report.records(j).jainFairness=sum(bits)^2/(numel(bits)*sum(bits.^2)); end
    if o.validationSamples>0
        mc=leo_sample_period_service(e.problemData,result.x,model.parameters.channel.ricianK, ...
            o.validationSamples,o.validationSeed);
        report.records(j).sampleMeanTotalBits=mc.meanTotalBits;
        report.records(j).sampleJointSuccessRate=mc.jointSuccessRate;
        report.records(j).sampleJointFailure95Upper=mc.jointFailure95Upper;
        report.solutions{j}.sampleValidation=mc;
    end
end
report.summary=leo_summarize_benchmark(report.records,e.methods);
temporary=[tempname(pairDir),'.mat']; save(temporary,'report','-v7');
[ok,message]=movefile(temporary,path); assert(ok,message);
leo_write_struct_csv(fullfile(pairDir,sprintf('seed_%.0f_runs.csv',seed)),report.records);
fprintf('V12_PAIR_SAVED seed=%.0f (%d/%d).\n',seed,index,numel(o.seeds));
end
