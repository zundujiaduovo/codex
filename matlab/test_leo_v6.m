function test_leo_v6()
%TEST_LEO_V6 固定默认种子、8并发、稳定离线码本及纯折线规格的回归。
assert(leo_stable_argmax([1,1+1e-12],1e-10)==1);
assert(leo_stable_argmax([1,1+1e-4],1e-10)==2);
p=leo_paper_parameters(); assert(p.seed==71669974 && p.system.maxStreams==8);
assert(p.system.K==32 && p.array.nX==8 && p.array.nY==8 && p.array.nBeams==32);
o=leo_benchmark_options(); assert(isequal(o.seeds,71669974));
p=leo_validate_parameters(p); before=rng; cleanup=onCleanup(@() rng(before)); %#ok<NASGU>
a=leo_build_codebook(p); rng(99,'twister'); b=leo_build_codebook(p);
expected=[1:6,8:13,15:23,25:30,32,34:37];
assert(isequal(a.selectedCandidateIndex,expected));
assert(isequal(a.phaseIndex,b.phaseIndex) && isequal(a.F,b.F));
base=tempname; directoryCleanup=onCleanup(@() cleanup_dir(base)); %#ok<NASGU>
opts=struct('methods',{{'initial'}},'budgetSeconds',12,'validationSamples',3, ...
 'verbose',false,'theoryOptions',struct('maxSeconds',0));
[report,fig]=run_leo_comparison(base,opts,false);
assert(isempty(fig) && report.runSeed==71669974 && strcmp(report.seedSource,'fixed_default'));
assert(report.problemData.maxStreams==8 && nnz(report.problemData.available)==623);
folder=report.options.outputDirectory;
assert(exist(fullfile(folder,'scenario_codebook.csv'),'file')==2);
assert(exist(fullfile(folder,'scenario_candidates.csv'),'file')==2);
assert(exist(fullfile(folder,'theoretical_bound_iterations.csv'),'file')==2);
assert(isequal(report.scenario.selectedCandidateIndex,expected));
data=leo_collect_plot_data(report); specs=leo_build_plot_specs(data);
for j=1:numel(specs)
 assert(~any(strcmp({specs(j).panels.kind},'bar')));
end
loaded=load(fullfile(folder,'benchmark.mat'));
assert(loaded.report.runSeed==71669974 && strcmp(loaded.report.seedSource,'fixed_default'));
fprintf('PASS: V6 fixed default seed, 8 concurrent users, stable codebook, scenario audit and line-only comparison specifications.\n');
end
function cleanup_dir(path)
if exist(path,'dir'), rmdir(path,'s'); end
end
