function report = leo_benchmark_case(model,options)
%LEO_BENCHMARK_CASE 第 13.3 节：同一物理样本上的多算法、多随机种子对比。
% 输入：run_leo_sinr 的未求解模型、实验选项；输出逐次记录、日程、统计及穷举参考。
% 共用预处理耗时按每个方法各记一次；穷举在所有启发式结束后运行，禁止先验泄漏。
problem = model.problem;
options = leo_benchmark_options(options,problem.data);
providedSchedule=model.xExample; commonFullStart=false;
if isfield(problem.data.design,'calibrationX')
    % 公共确定性校准日程属于已计时预处理，所有方法同样可用。
    providedSchedule=problem.data.design.calibrationX;
    commonFullStart=leo_requires_full_qos(problem.data) && all(problem.data.design.calibrationBits>=problem.data.qosTargetBits);
end
commonSeconds = model.timings.physicalProblemSeconds;
template = struct('method','','seed',0,'status','','solverStatus','','message','','fairness',NaN, ...
    'worstDemandRatio',NaN,'qosSatisfactionRate',NaN,'totalBits',NaN,'hardFeasible',false, ...
    'nominalTotalBits',NaN,'averageCompletion',NaN,'qosJointSuccessLower',NaN, ...
    'initialFairness',NaN,'initialTotalBits',NaN,'fairnessFloor',NaN, ...
    'fairnessUpperBound',NaN,'fairnessGap',NaN,'throughputUpperBoundBits',NaN, ...
    'throughputGapBits',NaN,'exactFairnessGap',NaN,'exactThroughputGapBits',NaN, ...
    'goalStatus','','fullQosFeasible',false,'feasibleTotalBits',NaN,'requiredFairnessFloor',NaN, ...
    'commonSeconds',commonSeconds,'proxyPreparationSeconds',0,'searchSeconds',NaN, ...
    'endToEndSeconds',NaN,'budgetSeconds',options.budgetSeconds,'budgetOverrunSeconds',NaN);
template.usesQuadraticProxy=false; template.initializationPolicy='common_original_candidates';
template.gainOverInitialPercent=NaN; template.upperGapPercent=NaN; template.knownLowerGapPercent=NaN;
template.searchEngine='original_objective';
template.objectiveMode='full_qos_sum';
if leo_is_lexicographic(problem.data), template.objectiveMode='lexicographic_max_min'; end
template.stage1Fairness=NaN; template.stage2Fairness=NaN; template.stage1FairnessGap=NaN;
template.stage1Certified=false; template.fairnessPreserved=false;
records = repmat(template,0,1); solutions = {};
for seed = options.seeds(:).'
    for j = 1:numel(options.methods)
        name = options.methods{j}; row = template; row.method = name; row.seed = seed;
        prebuiltProxy = any(strcmp(name,{'price_sb','price_sb_blockwise','price_sb_adaptive','price_sb_light', ...
            'price_local','price_local_adaptive','price_local_blockwise','price_sb_joint','price_local_joint', ...
            'price_miqp','proxy_milp','sb_minimax_fixed'}));
        if commonFullStart && ~strcmp(name,'proxy_milp'), prebuiltProxy=false; end
        if prebuiltProxy && isempty(model.surrogate)
            proxyTimer=tic; model.surrogate=leo_build_service_surrogates(problem);
            model.timings.proxySeconds=toc(proxyTimer);
        end
        if prebuiltProxy, row.proxyPreparationSeconds = model.timings.proxySeconds; end
        seconds = options.budgetSeconds-commonSeconds-row.proxyPreparationSeconds;
        result = [];
        if strcmp(name,'price_miqp') && exist('gurobi','file')==0
            row.status = 'unavailable'; row.message = 'Gurobi MATLAB interface is not installed.';
        elseif strcmp(name,'proxy_milp') && exist('intlinprog','file')==0 && exist('glpk','file')==0
            row.status = 'unavailable'; row.message = 'Requires MATLAB intlinprog or Octave GLPK.';
        elseif seconds<=0
            row.status = 'budget_exhausted_before_search'; row.message = 'Common preprocessing already exhausts the requested budget.';
        else
            method = options.method; method.seed = seed; method.maxSeconds = seconds; method.verbose = false;
            timer = tic;
            try
                solverProxy=[]; if prebuiltProxy, solverProxy=model.surrogate; end
                result = leo_run_benchmark_method(problem,solverProxy,providedSchedule,name,method);
                row.usesQuadraticProxy=~any(strcmp(name,{'initial','original_greedy','original_exchange','original_tabu','original_tabu_independent'}));
                if isfield(result,'searchEngine'), row.searchEngine=result.searchEngine;
                elseif row.usesQuadraticProxy, row.searchEngine='V9 candidate coordinator'; end
                if strcmp(name,'original_tabu_independent'), row.initializationPolicy='independent_original_candidates'; end
                service = problem.evaluate(result.x); % 最后统一校验硬约束、原始服务
                row.fullQosFeasible=all(service.userBits>=problem.data.qosTargetBits);
                row.requiredFairnessFloor=result.fairnessFloor;
                row.stage1Fairness=result.stage1.service.fairness;
                row.stage2Fairness=service.fairness;
                row.stage1FairnessGap=max(0,result.fairnessUpperBound-row.stage1Fairness);
                row.stage1Certified=row.stage1FairnessGap<=method.gapTolerance;
                row.fairnessPreserved=all(service.demandRatio>=result.fairnessFloor);
                if row.fullQosFeasible
                    row.goalStatus='full_qos_met'; row.feasibleTotalBits=service.totalBits;
                else
                    row.goalStatus='full_qos_not_found';
                end
                if leo_is_lexicographic(problem.data)
                    row.goalStatus='lexicographic_fairness_then_throughput';
                    row.feasibleTotalBits=service.totalBits;
                end
                if ~leo_requires_full_qos(problem.data) || row.fullQosFeasible
                    assert(all(service.demandRatio>=result.fairnessFloor));
                else
                    assert(isequal(result.stage2.x,result.stage1.x),'未达标时禁止启动吞吐阶段。');
                end
                row.status = 'completed'; row.hardFeasible = true;
                if isfield(result.stage1,'solver')
                    row.solverStatus = [result.stage1.solver.status,' / ',result.stage2.solver.status];
                elseif isfield(result.stage1,'status')
                    row.solverStatus = [result.stage1.status,' / ',result.stage2.status];
                end
                row.fairness = service.fairness; row.worstDemandRatio = min(service.demandRatio);
                row.qosSatisfactionRate = mean(service.demandRatio>=1); row.totalBits = service.totalBits;
                row.averageCompletion = mean(min(1,service.demandRatio));
                row.initialFairness = result.initial.service.fairness; row.initialTotalBits = result.initial.service.totalBits;
                if (leo_is_lexicographic(problem.data) || (row.fullQosFeasible && row.initialFairness==1)) && row.initialTotalBits>0
                    row.gainOverInitialPercent=100*(service.totalBits/row.initialTotalBits-1);
                end
                row.fairnessFloor = result.fairnessFloor; row.fairnessUpperBound = result.fairnessUpperBound;
                row.fairnessGap = result.fairnessGap; row.throughputUpperBoundBits = result.throughputUpperBoundBits;
                row.throughputGapBits = result.throughputGapBits;
            catch err
                row.status = 'failed'; row.message = err.message;
                row.fullQosFeasible=false; row.feasibleTotalBits=NaN; row.goalStatus='not_evaluated';
                if strcmp(err.identifier,'leo:solverUnavailable'), row.status = 'unavailable'; end
            end
            row.searchSeconds = toc(timer);
            row.endToEndSeconds = commonSeconds+row.proxyPreparationSeconds+row.searchSeconds;
            row.budgetOverrunSeconds = max(0,row.endToEndSeconds-options.budgetSeconds);
            % 独立报告验证：不计入搜索时间，不用这些样本/指标选择日程。
            if strcmp(row.status,'completed') && isfield(problem.data.design,'nominalSignalW')
                nominal = leo_evaluate_nominal_service(problem.data,result.x);
                row.nominalTotalBits = nominal.totalBits;
                result.nominalService = nominal;
                if any(strcmp(problem.data.design.serviceModel,{'periodic_chernoff','periodic_multilevel'}))
                    cert = leo_certify_period_qos(problem.data,result.x);
                    row.qosJointSuccessLower = cert.jointSuccessLower;
                    result.qosCertificate = cert;
                end
            end
        end
        records(end+1,1) = row; solutions{end+1,1} = result; %#ok<AGROW>
        if options.verbose
            fprintf('%-23s seed=%d %-12s s=%.9g V=%.6g Mbit wall=%.3f s\n', ...
                name,seed,row.status,row.fairness,row.totalBits/1e6,row.endToEndSeconds);
            if ~isempty(row.solverStatus), fprintf('  Stop: %s\n',row.solverStatus); end
            if ~isempty(row.goalStatus)
                if leo_is_lexicographic(problem.data)
                    fprintf('  Goal: uncapped max-min first; stage-1 s=%.9g, preserved floor=%.9g, final s=%.9g.\n',row.stage1Fairness,row.requiredFairnessFloor,row.stage2Fairness);
                else
                    fprintf('  Goal: %s (full-user QoS floor 1).\n',row.goalStatus);
                end
            end
            if ~isempty(row.message), fprintf('  %s\n',row.message); end
        end
    end
end
% 精确基准有独立预算；它是证书，不参与各方法的输入或初始化。
reference = [];
if options.exhaustive
    exhaustive = leo_exhaustive_options(struct('verbose',options.verbose));
    reference = leo_exhaustive_search(problem,exhaustive);
    if reference.optimal
        for j = 1:numel(records)
            if ~strcmp(records(j).status,'completed'), continue; end
            gap = reference.fairness-records(j).fairness;
            assert(gap>=-1e-10,'原始穷举最优值与方法结果不一致。');
            records(j).exactFairnessGap = max(0,gap);
            % 吞吐最优仅能在同一公平门槛下比较；不同门槛保留 NaN。
            if abs(gap)<=1e-12 && all(solutions{j}.service.demandRatio>=reference.fairness)
                records(j).exactThroughputGapBits = max(0,reference.totalBits-records(j).totalBits);
            end
        end
    end
end
if isfield(model,'codebook') && isfield(model.codebook,'selectedCandidateIndex')
    report.scenario=struct('selectedCandidateIndex',model.codebook.selectedCandidateIndex, ...
        'gridIndex',model.codebook.gridIndex,'phaseIndex',model.codebook.phaseIndex, ...
        'userLatDeg',model.users.latDeg,'userLonDeg',model.users.lonDeg,'selectionRule',model.codebook.selectionRule);
end
report.parameters = model.parameters; report.options = options;
report.problemData = problem.data; report.records = records; report.solutions = solutions;
report.exhaustive = reference; report.summary = struct([]);
% 算法结果先落盘；汇总或绘图失败时仍可恢复，不必重新求解所有方法。
if ~isempty(options.outputDirectory)
    if ~exist(options.outputDirectory,'dir'), mkdir(options.outputDirectory); end
    save(fullfile(options.outputDirectory,'raw_benchmark.mat'),'report','-v7');
end
report.summary = leo_summarize_benchmark(records,options.methods);
report.scope = 'Baseline O2/O4, fixed blocks, all physical candidates; optional extensions listed separately in IMPLEMENTATION_STATUS.md.';
end
