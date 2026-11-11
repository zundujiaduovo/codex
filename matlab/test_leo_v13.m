function report = test_leo_v13()
%TEST_LEO_V13 实际64用户模型：1/4准入、16流可行、17流拒绝、版本隔离和导出。
root=fileparts(fileparts(mfilename('fullpath'))); CHECK_V13_INSTALLATION(root);
p=leo_validate_parameters(leo_v13_parameters());
assert(p.system.K==64 && p.array.nBeams==64 && p.system.maxStreams==16);
assert(p.system.maxStreams/p.array.nBeams==.25 && p.system.nRF==16);
assert(p.system.streamPowerW==10 && p.system.maxPowerW==160);
assert(p.system.qosTargetBits(64)==1e6 && p.problem.referenceBits==64e6);
assert(strcmp(p.problem.objectiveMode,'lexicographic_max_min'));
[lat,lon]=leo_reference_users_64(); [oldLat,oldLon]=leo_reference_users_32();
assert(numel(lat)==64 && numel(lon)==64 && size(unique([lat;lon].','rows'),1)==64);
assert(isequal(lat(1:32),oldLat) && isequal(lon(1:32),oldLon));
before=rng; rng(7,'twister'); a=leo_generate_users(p); rng(999,'twister'); b=leo_generate_users(p); rng(before);
assert(isequal(a.latDeg,b.latDeg) && isequal(a.lonDeg,b.lonDeg));
angle=acos(max(-1,min(1,cos(lat*pi/180).*cos(lon*pi/180))));
assert(all(angle<=200e3/p.earth.aM+1e-12));
directory=tempname; mkdir(directory); cleanup=onCleanup(@() remove(directory)); %#ok<NASGU>
options=struct('prepareOnly',true,'validationSamples',0,'budgetSeconds',20, ...
    'method',struct('fairnessRounds',1,'throughputRounds',1,'originalSearchRounds',1, ...
        'sbSteps',10,'sbTrajectories',2,'localRestarts',2,'randomInitialSchedules',0, ...
        'recoveryEvaluations',4,'polishMoves',2,'audit',struct('enabled',false)), ...
    'fairnessCertificateOptions',struct('maxSeconds',0,'maxNodes',1,'verbose',false), ...
    'throughputCertificateOptions',struct('maxSeconds',0,'maxNodes',1,'verbose',false));
[experiment,~]=run_leo_v13_comparison(directory,options,false);
assert(strcmp(experiment.version,'V13 based on V12: 64 users, 64 beams, 16 streams'));
assert(isequal(experiment.methods,{'Tabu','SB','Local','Greedy'}));
data=experiment.problemData; assert(isequal(data.shape,[64,20]) && data.maxStreams==16);
assert(all(any(data.available,2)),'The fixed V13 layout must offer every user a resource.');
% 用实际波束冲突约束选17个不同波束的可用用户，分别验证16和17并发。
checked=false;
for m=1:data.shape(2)
    ids=find(data.available(:,m)); [~,at]=unique(data.beamIndex(ids,m));
    if numel(at)<17, continue; end
    ids=ids(at); x=false(data.shape); x(ids(1:16),m)=true;
    assert(all(data.hard.A*double(x(:))<=data.hard.rhs));
    service=leo_evaluate_service(data,x); assert(isfinite(service.totalBits));
    x(ids(17),m)=true; assert(any(data.hard.A*double(x(:))>data.hard.rhs));
    checked=true; break;
end
assert(checked,'The 64-beam scene should expose at least 17 distinct candidate beams.');
% V12入口不能把V13同目录结果当作自己的旧实验。
rejected=false;
try, run_leo_v12_comparison(directory,options,false); catch err
    rejected=~isempty(strfind(err.message,'different version/objective/protocol'));
end
assert(rejected);
options.prepareOnly=false; [report,~]=run_leo_v13_comparison(directory,options,false);
assert(numel(report.records)==4 && all(strcmp({report.records.status},'completed')));
assert(report.fairnessCertificate.upper<report.fairnessCertificate.coarseUpper);
for j=1:4
    assert(report.records(j).fairnessPreserved);
    assert(all(sum(report.solutions{j}.x,1)<=16));
    assert(isequal(report.solutions{j}.initial.x,report.solutions{1}.initial.x));
end
run_leo_v12_verify_exports(directory);
spec=jsondecode(fileread(fullfile(directory,'v13_specs.json')));
assert(strcmp(spec.name,'v13_uncapped_lexicographic') && ~isempty(strfind(spec.title,'K=64, NB=64, L=16')));
spec=jsondecode(fileread(fullfile(directory,'v13_diagnostic_specs.json')));
assert(numel(spec)==2 && strcmp(spec(1).name,'v13_iteration_convergence'));
assert(isequal({report.records.method},{'Tabu','SB','Local','Greedy'}));
assert(exist(fullfile(directory,'stopping_summary.csv'),'file')==2);
% 旧方法ID和未记录停止信息的已有成绩可只重画；原始benchmark字节不变。
legacy=report; legacy.options.methods=cellfun(@leo_method_id,legacy.options.methods,'UniformOutput',false);
for j=1:numel(legacy.records)
    legacy.records(j).method=leo_method_id(legacy.records(j).method);
    for phase=1:2
        field=sprintf('stage%d',phase); legacy.solutions{j}.(field)=rmfield(legacy.solutions{j}.(field),'stopping');
    end
end
oldDirectory=fullfile(directory,'legacy_names'); mkdir(oldDirectory);
original=report; report=legacy; save(fullfile(oldDirectory,'benchmark.mat'),'report','-v7'); report=original;
oldBytes=fileread_bytes(fullfile(oldDirectory,'benchmark.mat'));
run_leo_v13_replot(oldDirectory,false);
assert(isequal(oldBytes,fileread_bytes(fullfile(oldDirectory,'benchmark.mat'))));
oldSpec=jsondecode(fileread(fullfile(oldDirectory,'v13_specs.json')));
assert(isequal(oldSpec.panels(1).labels(:).',{'Tabu','SB','Local','Greedy'}));
assert(isequal({oldSpec.panels(3).series.name},{'Tabu','SB','Local','Greedy'}));
stops=leo_stopping_rows(legacy); assert(all(isnan([stops.validRelativeGap])));
path=fullfile(directory,'pairs','seed_71669974.mat'); marker=fileread_bytes(path);
[again,~]=run_leo_v13_comparison(directory,options,false);
assert(isequaln(again.records,report.records) && isequal(marker,fileread_bytes(path)));
fprintf('PASS: V13 real 64-user model, 64 beams, 16/17 admission boundary, four paired methods, strict phase-2 fairness, original-model CSV audit, V13 plots and cache isolation/resume.\n');
end
function remove(directory)
if exist(directory,'dir')==7, rmdir(directory,'s'); end
end
function payload=fileread_bytes(path)
fid=fopen(path,'rb'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
payload=fread(fid,Inf,'*uint8');
end
