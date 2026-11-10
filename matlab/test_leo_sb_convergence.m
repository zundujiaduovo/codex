function test_leo_sb_convergence()
%TEST_LEO_SB_CONVERGENCE 每种SB曲线、真实时间、旧日志、阶段跳过及固定Ising范围。
problem=fixture(); o=leo_method_options(struct('fairnessRounds',2,'throughputRounds',2, ...
 'sbSteps',20,'sbTrajectories',3,'sbCheckpoint',5,'randomInitialSchedules',0, ...
 'recoveryEvaluations',12,'recoveryPasses',2,'localRestarts',2,'verbose',false));
methods={'price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light', ...
 'sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio','original_tabu','price_local_adaptive'};
model=struct('problem',problem,'parameters',struct('seed',13), ...
 'xExample',problem.precheck.witness,'surrogate',leo_build_service_surrogates(problem));
model.timings=struct('physicalProblemSeconds',.001,'proxySeconds',.001);
opts=struct('methods',{methods},'seeds',13,'budgetSeconds',2,'exhaustive',false, ...
 'makePlots',false,'verbose',false,'method',o);
report=leo_benchmark_case(model,opts);
assert(all(strcmp({report.records.status},'completed')));
for j=1:7
 result=report.solutions{j};
 for phase=1:2
  stage=result.(sprintf('stage%d',phase)); c=stage.checkpoints;
  assert(numel(c.elapsedSeconds)==numel(c.kind) && all(diff(c.elapsedSeconds)>=0));
  assert(c.savedTotalBits(1)==stage.initialService.totalBits && c.savedTotalBits(end)==stage.service.totalBits);
  assert(c.elapsedSeconds(end)<=stage.elapsedAtEndSeconds);
  if phase==2, assert(all(diff(c.savedTotalBits)>=-1e-10)); end
 end
end
directory=tempname; cleanup=onCleanup(@() cleanup_dir(directory)); %#ok<NASGU>
before=rng; [files,specs]=run_leo_sb_convergence(report,directory,false); assert(isequal(rng,before));
assert(isempty(files) && numel(specs)==9);
assert(exist(fullfile(directory,'sb_convergence_specs.json'),'file')==2);
assert(exist(fullfile(directory,'sb_convergence_time.csv'),'file')==2);
data=leo_collect_plot_data(report);
for j=1:numel(report.records)
 rows=data.progress(strcmp({data.progress.method},report.records(j).method));
 assert(all(diff([rows.seconds])>=0));
 assert(all([rows.seconds]<=report.records(j).endToEndSeconds+1e-8));
end
% 代表曲线按已有日志取值，不能用cummax掩盖公平阶段的服务下降。
manual=data; manual.methods={'price_sb'}; manual.requireFullQos=false;
manual.progress=repmat(data.progress(1),3,1);
for j=1:3
 manual.progress(j).method='price_sb'; manual.progress(j).seed=13;
 times=[1,20,60]; manual.progress(j).seconds=times(j); manual.progress(j).fairness=.1*j;
end
values=[10,8,12]; for j=1:3, manual.progress(j).totalBits=values(j)*1e6; end
s=leo_build_sb_convergence_specs(manual); assert(isequal(s(2).panels(1).series(1).y,values));
assert(isequal(s(2).panels(1).series(1).x,[1,20,60]));
manual.requireFullQos=true; manual.progress(3).fairness=1;
s=leo_build_sb_convergence_specs(manual); y=s(2).panels(1).series(1).y;
assert(all(isnan(y(1:2))) && y(3)==12);
% 能量只能来自同一个固定调用，不能拼接别的价格轮/资源。
e=data.energy(strcmp({data.energy.method},'price_sb') & [data.energy.phase]==2);
assert(~isempty(e)); first=e(1);
selected=e([e.resource]==first.resource & [e.priceIteration]==first.priceIteration & strcmp({e.member},first.member));
manual=data; manual.methods={'price_sb'};
fake=selected; for j=1:numel(fake), fake(j).priceIteration=999; fake(j).minimum=999; end
manual.energy=[manual.energy;fake];
s=leo_build_sb_convergence_specs(manual);
assert(isequal(s(2).panels(4).series(1).y,[selected.minimum]));
% 旧V7的日志不含checkpoints仍可画；不执行的阶段不制造迭代/能量曲线。
legacy=report;
for j=1:7
 for phase=1:2
  name=sprintf('stage%d',phase); legacy.solutions{j}.(name)=rmfield(legacy.solutions{j}.(name),'checkpoints');
 end
end
[~,old]=run_leo_sb_convergence(legacy,fullfile(directory,'legacy'),false); assert(numel(old)==9);
missing=data; missing.methods={'price_sb'}; missing.progress=struct([]); missing.events=struct([]); missing.energy=struct([]);
s=leo_build_sb_convergence_specs(missing);
assert(all(arrayfun(@(p) isempty(p.series),s(2).panels)));
% 支持列向量methods及MAT路径重画，不依赖原算法再次求解。
data.methods=data.methods.'; assert(numel(leo_build_sb_convergence_specs(data))==9);
save(fullfile(directory,'benchmark.mat'),'report','-v7');
[~,loaded]=run_leo_sb_convergence(fullfile(directory,'benchmark.mat'),fullfile(directory,'loaded'),false);
assert(numel(loaded)==9);
fprintf('PASS: per-SB convergence, true checkpoint values/times, phase omissions, fixed-Ising scope, legacy/MAT loading and missing-data handling.\n');
end
function cleanup_dir(path)
if exist(path,'dir'), rmdir(path,'s'); end
end
function problem=fixture()
p=leo_default_parameters(); p.statistics.serviceModel='slot_union'; p.system.K=4; p.system.maxStreams=2;
p.system.bandwidthHz=10; p.system.qosTargetBits=100;
p.time.nSlots=4; p.time.blockSlots=2; p.time.slotDurationS=.5;
p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(4,2); b.index=repmat([1;1;2;3],1,2);
d.signalW=[1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW=repmat([1,2,1.5,3],4,1); d.beamPowerW=zeros(4,3,4);
for t=1:4, d.beamPowerW(:,:,t)=[2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem=leo_form_problem(p,r,b,d);
end
