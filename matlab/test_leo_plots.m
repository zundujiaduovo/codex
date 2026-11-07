function test_leo_plots()
%TEST_LEO_PLOTS 验证图表计数、真实时间、有效界、SB 能量、缺失值和导出接口。
% 接口标注：
% 输入：无；构造独立数值基准及边界算例。
% 输出：无返回值；失败时抛出断言，成功时打印检查组数。
% 输入：无；输出：通过检查组数；无需图形后端，不以作图外观代替数值验证。
checks = 0; problem = fixture();
o = leo_method_options(struct('fairnessRounds',3,'throughputRounds',2, ...
    'sbSteps',30,'sbCheckpoint',10,'sbTrajectories',3,'randomInitialSchedules',0, ...
    'localRestarts',2,'recoveryEvaluations',8,'recoveryPasses',1,'verbose',false));
model.problem = problem; model.parameters = struct('seed',1);
model.xExample = problem.precheck.witness;
model.surrogate = leo_build_service_surrogates(problem);
model.timings.physicalProblemSeconds = .001; model.timings.proxySeconds = .002;
opts = leo_benchmark_options(struct('methods',{{'initial','original_greedy','original_exchange', ...
    'price_sb','price_local','sb_reference_portfolio'}},'seeds',13,'budgetSeconds',20, ...
    'exhaustive',false,'makePlots',false,'verbose',false,'method',o));
report = leo_benchmark_case(model,opts); report.caseName = 'test';
assert(all(strcmp({report.records.status},'completed')));
before = rng; data = leo_collect_plot_data(report); assert(isequal(rng,before));
assert(data.representativeSeed==13 && data.referenceBits==777);
for r = 1:numel(report.records)
    result = report.solutions{r}; c = data.counts(r);
    if strcmp(c.method,'sb_reference_portfolio'), continue; end
    if isfield(result.stage1,'rounds')
        h1 = result.stage1.history; h2 = result.stage2.history;
        assert(c.priceRounds1==result.stage1.rounds && c.priceRounds2==result.stage2.rounds);
        assert(c.completeRounds1==sum(h1.completePriceRound));
        assert(c.sbIntegrationSteps==sum(h1.sbSteps)+sum(h2.sbSteps));
        assert(c.sbTrajectorySteps==c.sbIntegrationSteps*o.sbTrajectories);
    else
        assert(c.searchSteps1==result.stage1.iterations && isnan(c.priceRounds1));
    end
end
checks = checks+1;

% 组合搜索统计所有分支，不只统计获胜分支。
index = find(strcmp({data.counts.method},'sb_reference_portfolio'));
members = report.solutions{index}.memberRuns; totalSteps = 0; totalRounds = 0;
assert(numel(members)==3);
for j = 1:numel(members)
    for stage = {'stage1','stage2'}
        s = members{j}.(stage{1}); totalSteps = totalSteps+sum(s.history.sbSteps);
        totalRounds = totalRounds+s.rounds;
    end
end
assert(data.counts(index).sbIntegrationSteps==totalSteps);
assert(data.counts(index).priceRounds1+data.counts(index).priceRounds2==totalRounds);
checks = checks+1;

% 价格轨迹的上界使用原问题 Dref，不假定 Dref=sum(q)。
index = find(strcmp({data.counts.method},'price_sb')); solved = report.solutions{index};
for phase = 1:2
    stage = solved.(sprintf('stage%d',phase));
    events = data.events(strcmp({data.events.method},'price_sb') & [data.events.phase]==phase);
    assert(events(1).iteration==0 && events(1).fairness==stage.initialService.fairness);
    events = events([events.iteration]>0);
    expected = stage.history.upperBound; if phase==2, expected = expected*777; end
    assert(numel(events)==stage.rounds && max(abs([events.upperBound]-expected))<1e-10);
    if phase==1, achieved = [events.fairness]; else, achieved = [events.totalBits]; end
    assert(all([events.upperBound]>=achieved-1e-9));
end
assert(numel(data.prices)>0 && numel(data.energy)>0); checks = checks+1;

% 每段记录必须落在真实测量结束之前；原始服务日程仍满足全部约束。
for r = 1:numel(report.records)
    row = report.records(r);
    points = data.progress(strcmp({data.progress.method},row.method));
    assert(all([points.seconds]>=row.commonSeconds+row.proxyPreparationSeconds));
    assert(all([points.seconds]<=row.endToEndSeconds+1e-8));
    assert(points(end).fairness==row.fairness && points(end).totalBits==row.totalBits);
end
checks = checks+1;

% SB 只画同一个固定 Ising 调用的历史最好能量，检查单调性和最终值。
qubo = leo_build_resource_qubo(problem.data,model.surrogate.lower,1,ones(4,1)/400,o);
ising = leo_qubo_to_ising(qubo); sb = leo_ballistic_sb(ising,o,zeros(ising.nBits,1),[]);
h = sb.history;
assert(h.step(1)==0 && h.step(end)==sb.steps && sb.steps==o.sbSteps);
assert(all(diff(h.minimum)<=1e-12) && all(diff(h.median)<=1e-12) && all(diff(h.maximum)<=1e-12));
assert(abs(h.minimum(end)-min(sb.energy))<1e-12 && abs(h.median(end)-median(sb.energy))<1e-12);
assert(all(h.minimum<=h.median & h.median<=h.maximum)); checks = checks+1;

specs = leo_build_plot_specs(data); assert(numel(specs)==18);
assert(numel(unique({specs.name}))==18);
for j = 1:numel(specs)
    for k = 1:numel(specs(j).panels)
        p = specs(j).panels(k); assert(isequal(size(p.z),p.zShape));
        for s = p.series(:).'
            assert(numel(s.x)==numel(s.y));
            if ~isempty(s.low), assert(all(s.low<=s.y | isnan(s.y)) && all(s.high>=s.y | isnan(s.y))); end
        end
    end
end
checks = checks+1;

% 旧结果无迭代日志：必须保留未知，不能从最终解猜次数。
old = report;
index = find(strcmp({old.records.method},'original_greedy'));
for name = {'stage1','stage2'}
    old.solutions{index}.(name{1}) = rmfield(old.solutions{index}.(name{1}),{'iterations','history'});
end
portfolio = find(strcmp({old.records.method},'sb_reference_portfolio'));
old.solutions{portfolio} = rmfield(old.solutions{portfolio},{'memberRuns','portfolioHistory'});
legacy = leo_collect_plot_data(old);
assert(isnan(legacy.counts(index).searchSteps1) && isnan(legacy.counts(portfolio).priceRounds1));
assert(numel(leo_build_plot_specs(legacy))==18); checks = checks+1;

% 全部不可用时图组仍可生成，未运行不伪造为零成绩。
missing = report; missing.options.methods = {'price_miqp'};
missing.records = report.records(1); missing.records.method = 'price_miqp';
missing.records.status = 'unavailable'; missing.solutions = {[]};
absent = leo_collect_plot_data(missing);
assert(isnan(absent.counts.priceRounds1) && isempty(absent.representatives));
assert(numel(leo_build_plot_specs(absent))==18); checks = checks+1;

% 真实导出和重载，不要求图形后端。
directory = tempname; mkdir(directory); cleanup = onCleanup(@() rmdir(directory,'s')); %#ok<NASGU>
[files,exported] = run_leo_plot_results(report,directory,false);
assert(isempty(files) && numel(exported.counts)==numel(report.records));
assert(exist(fullfile(directory,'iterations.csv'),'file')~=0);
loaded = load(fullfile(directory,'plot_data.mat')); assert(isequaln(loaded.plotData,exported));
parsed = jsondecode(fileread(fullfile(directory,'plot_specs.json'))); assert(numel(parsed)==18);
checks = checks+1;

% 完整基准导出必须经过用户/日程表构造，不能只验证绘图数据导出。
leo_export_benchmark(report,directory);
loaded = load(fullfile(directory,'benchmark.mat'));
assert(isequaln(loaded.report,report));
completed = sum(strcmp({report.records.status},'completed'));
userLines = regexp(strtrim(fileread(fullfile(directory,'user_service.csv'))),'\r?\n','split');
scheduleLines = regexp(strtrim(fileread(fullfile(directory,'schedules.csv'))),'\r?\n','split');
assert(numel(userLines)==1+completed*report.problemData.shape(1));
assert(numel(scheduleLines)==1+completed*prod(report.problemData.shape));
assert(~isempty(strfind(userLines{1},'demandRatio'))); %#ok<STREMP>
assert(~isempty(strfind(scheduleLines{1},'selected'))); %#ok<STREMP>
checks = checks+1;

% 全部不可用时仍能导出；两张明细表为空，状态记录不能变成成功。
emptyDirectory = fullfile(directory,'unavailable');
leo_export_benchmark(missing,emptyDirectory);
loaded = load(fullfile(emptyDirectory,'benchmark.mat'));
assert(strcmp(loaded.report.records.status,'unavailable'));
assert(isempty(strtrim(fileread(fullfile(emptyDirectory,'user_service.csv')))));
assert(isempty(strtrim(fileread(fullfile(emptyDirectory,'schedules.csv')))));
parsed = jsondecode(fileread(fullfile(emptyDirectory,'plot_specs.json')));
assert(numel(parsed)==18);
checks = checks+1;
fprintf('PASS: %d plotting data and iteration logging test groups (no graphics backend required).\n',checks);
end

function problem = fixture()
p = leo_default_parameters(); p.system.K = 4; p.system.maxStreams = 2;
p.system.bandwidthHz = 10; p.system.qosTargetBits = 100; p.problem.referenceBits = 777;
p.time.nSlots = 4; p.time.blockSlots = 2; p.time.slotDurationS = .5;
p.time.baseOverheadS = 0; p.time.configOverheadS = 0;
p = leo_validate_parameters(p); r = leo_build_resources(p);
b.available = true(4,2); b.index = repmat([1;1;2;3],1,2);
d.signalW = [1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW = repmat([1,2,1.5,3],4,1); d.beamPowerW = zeros(4,3,4);
for t = 1:4, d.beamPowerW(:,:,t) = [2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem = leo_form_problem(p,r,b,d);
end
