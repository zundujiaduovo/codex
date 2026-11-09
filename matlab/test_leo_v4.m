function test_leo_v4()
%TEST_LEO_V4 论文参考参数、单种子及完整对比入口的回归检查。
before = rng; seed = leo_random_seed(); after = rng;
assert(isequal(before,after) && isscalar(seed) && seed>=0 && seed<=2^32-1 && seed==fix(seed));
p = leo_paper_parameters();
assert(p.system.carrierHz==4e9 && p.channel.ricianKDb==12);
assert(p.channel.elementGainDbi==6 && p.channel.receiveGainDbi==1 && strcmp(p.users.layout,'reference32'));
opts = leo_benchmark_options(struct('seeds',429756090)); assert(numel(opts.methods)==16);
base = tempname; cleanup = onCleanup(@() cleanup_dir(base)); %#ok<NASGU>
o = struct('methods',{{'initial'}},'seeds',429756090,'budgetSeconds',12, ...
    'verbose',false,'validationSamples',5,'theoryOptions',struct('maxSeconds',0));
[report,fig] = run_leo_comparison(base,o,false); %#ok<ASGLU>
assert(isempty(fig) && report.runSeed==429756090 && report.validationSeed==429860819);
assert(report.validationSamples==5 && strcmp(report.parameters.users.layout,'reference32'));
assert(strcmp(report.records(1).status,'completed'));
assert(exist(fullfile(base,'seed_429756090','run_seed.csv'),'file')==2);
assert(exist(fullfile(base,'seed_429756090','theoretical_bound_summary.csv'),'file')==2);
assert(report.theory.upperBits>=report.theory.lowerBits);
fprintf('PASS: V4 paper parameters, one seed, end-to-end comparison and bound.\n');
end

function cleanup_dir(path)
if exist(path,'dir'), rmdir(path,'s'); end
end
