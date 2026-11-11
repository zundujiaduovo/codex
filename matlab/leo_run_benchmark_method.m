function result = leo_run_benchmark_method(problem,proxy,provided,name,options)
%LEO_RUN_BENCHMARK_METHOD 第 13.3 节实验分派；所有求解均只收到同一模型/初始化。
% 输入：原问题、minimax 代理、提供日程、方法名、方法预算；输出方法的原始可行结果。
switch name
    case {'sb_v12_lexicographic','local_v12_lexicographic'}
        legacy=leo_v8_method_options(); fields=fieldnames(legacy);
        for j=1:numel(fields)
            if isfield(options,fields{j}), legacy.(fields{j})=options.(fields{j}); end
        end
        legacy.blockwiseOriginalAccept=true;
        if strcmp(name,'sb_v12_lexicographic'), legacy.innerSolver='sb'; else, legacy.innerSolver='local'; end
        result=leo_v12_solve_schedule(problem,[],legacy,provided);
        result.usesQuadraticProxy=true; result.usesProvidedSchedule=~isempty(provided);
        result.searchEngine='V12 uncapped adaptation of V10/V8';
    case {'sb_v8_blockwise','local_v8_blockwise'}
        assert(~leo_is_lexicographic(problem.data),'Use sb_v12_lexicographic/local_v12_lexicographic for the V12 objective.');
        % 冻结V8引擎：只传V8已有参数，禁止混入V9扰动/候选池/联合搜索。
        legacy=leo_v8_method_options(); fields=fieldnames(legacy);
        for j=1:numel(fields)
            if isfield(options,fields{j}), legacy.(fields{j})=options.(fields{j}); end
        end
        legacy.blockwiseOriginalAccept=true;
        if strcmp(name,'sb_v8_blockwise'), legacy.innerSolver='sb'; else, legacy.innerSolver='local'; end
        result=leo_v8_solve_schedule(problem,[],legacy,provided);
        result.usesQuadraticProxy=true; result.usesProvidedSchedule=~isempty(provided);
        result.searchEngine='V8 frozen cd4ba09';
    case {'initial','original_greedy','original_exchange','original_tabu'}
        kind = strrep(name,'original_','');
        result = leo_solve_original_search(problem,kind,options,provided);
    case 'original_tabu_independent'
        result = leo_solve_original_search(problem,'tabu',options,[]);
    case 'proxy_milp'
        result = leo_solve_proxy_milp(problem,proxy,options,provided);
    case 'sb_reference_portfolio'
        % 三个独立参考点搜索平分剩余总预算，结果按原始公平/吞吐择优。
        timer = tic; modes = {'zero','minimax','current_schedule'}; result = [];
        totalBudget = options.maxSeconds; minimumSetup = 0;
        members = {}; portfolioHistory = [];
        for j = 1:numel(modes)
            remaining = totalBudget-toc(timer);
            if remaining<=minimumSetup, break; end
            local = options; local.innerSolver = 'sb'; local.referenceMode = modes{j}; local.refreshEvery = 0;
            local.throughputReferenceMode=modes{j};
            local.seed=mod(double(options.seed)+7919*j,2^32);
            local.maxSeconds = remaining/(numel(modes)-j+1);
            memberOffset = toc(timer);
            candidate = leo_solve_schedule(problem,[],local,provided);
            minimumSetup = max(minimumSetup,candidate.initializationSeconds);
            if isempty(result) || leo_service_is_better(candidate.service,result.service,'fairness',0), result = candidate; end
            member.name = modes{j}; member.offsetSeconds = memberOffset;
            member.elapsedSeconds = toc(timer)-memberOffset;
            member.stage1 = rmfield(candidate.stage1,'proxy');
            member.stage2 = rmfield(candidate.stage2,'proxy');
            members{end+1} = member; %#ok<AGROW>
            portfolioHistory = leo_record_search_step(portfolioHistory,result.service,j,toc(timer),NaN);
        end
        if isempty(result), result = leo_solve_schedule(problem,[],options,provided); end
        result.elapsedSeconds = toc(timer);
        result.memberRuns = members; result.portfolioHistory = portfolioHistory;
    otherwise
        options.innerSolver = 'sb';
        if any(strcmp(name,{'price_local','price_local_adaptive','price_local_blockwise','price_local_joint'})), options.innerSolver = 'local'; end
        if strcmp(name,'price_miqp'), options.innerSolver = 'miqp'; end
        if any(strcmp(name,{'price_sb_blockwise','price_sb_adaptive','price_sb_light','price_local_adaptive', ...
                'price_local_blockwise','price_sb_joint','price_local_joint'}))
            options.blockwiseOriginalAccept = true;
        end
        if any(strcmp(name,{'price_sb_joint','price_local_joint'})), options.jointCandidateSearch=true; end
        if any(strcmp(name,{'price_sb_adaptive','price_sb_light','price_local_adaptive'}))
            options.refreshEvery = 1;
        end
        if strcmp(name,'price_sb_light')
            options.sbSteps = 100; options.sbTrajectories = 8;
        end
        if strcmp(name,'sb_zero')
            options.referenceMode = 'zero'; options.refreshEvery = 0; proxy = [];
            options.throughputReferenceMode='zero';
        elseif strcmp(name,'sb_current_fixed')
            options.referenceMode = 'current_schedule'; options.refreshEvery = 0; proxy = [];
            options.throughputReferenceMode='current_schedule';
        elseif strcmp(name,'sb_minimax_fixed')
            options.refreshEvery = 0;
            options.throughputReferenceMode='minimax';
        end
        result = leo_solve_schedule(problem,proxy,options,provided);
end
end
