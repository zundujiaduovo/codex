function model = run_leo_sinr(p)
%RUN_LEO_SINR 主入口：建模、代理；可选两阶段拉格朗日 SB 和原始问题穷举。
% 接口标注：
% 输入：p：可选完整参数；默认 32 波束、8 并发、50 ms 固定块。
% 输出：model：物理模型、原问题、代理及启用时的 method/exhaustive 求解结果。
% 保留原入口名称以兼容前一版，无附加 MATLAB 工具箱依赖。
% 用法：model=run_leo_sinr(); 或修改 leo_default_parameters() 后传入。
if nargin<1, p = leo_default_parameters(); end
modelTimer = tic;
p = leo_validate_parameters(p);
previousRng = rng;
restoreRng = onCleanup(@() rng(previousRng)); %#ok<NASGU>
rng(p.seed,'twister');
model.parameters = p;
model.resources = leo_build_resources(p);
model.codebook = leo_build_codebook(p); % 用户生成之前冻结码本
model.codebookCoverage = leo_check_codebook_coverage(p,model.codebook);
model.users = leo_generate_users(p);
model.orbit = leo_predict_orbit(p,model.resources);
model.geometry = leo_compute_geometry(p,model.users,model.orbit);
model.beams = leo_assign_beams(p,model.resources,model.geometry,model.codebook);
model.channel = leo_large_scale_channel(p,model.geometry);
model.fading = leo_generate_fading(p,model.geometry,model.beams,model.channel);
model.link = leo_link_coefficients(p,model.resources,model.beams,model.channel);
model.xExample = leo_example_selection(p,model.resources,model.beams);
model.sinr = leo_compute_sinr(p,model.resources,model.beams,model.channel, ...
    model.fading,model.link,model.codebook,model.xExample);
model.design = leo_prepare_design_service(p,model.resources,model.beams,model.channel,model.link);
model.problem = leo_form_problem(p,model.resources,model.beams,model.design);
model.exampleService = model.problem.evaluate(model.xExample);
% 仅演示第二阶段构造；采用预检见证日程的公平值，不是阶段 1 最优值。
model.problem.stage2Example = model.problem.makeStage2(model.problem.precheck.witness);
model.timings.physicalProblemSeconds = toc(modelTimer);
proxyTimer = tic;
if strcmp(p.surrogate.referenceMode,'current_schedule')
    model.surrogate = leo_build_service_surrogates(model.problem,'current_schedule',model.problem.precheck.witness);
else
    model.surrogate = leo_build_service_surrogates(model.problem,p.surrogate.referenceMode);
end
model.exampleBounds = leo_evaluate_service_bounds(model.problem,model.surrogate,model.xExample);
model.timings.proxySeconds = toc(proxyTimer);
model.timings.totalBuildSeconds = toc(modelTimer);
fprintf('K=%d, T=%d, M=%d, Na=%d, NB=%d, L=%d\n',p.system.K, ...
    p.time.nSlots,model.resources.nResources,p.array.nElements, ...
    model.codebook.nBeams,p.system.maxStreams);
fprintf('Available user-resource pairs: %d/%d; codebook sampled holes: %.2f%%\n', ...
    nnz(model.beams.available),numel(model.beams.available), ...
    100*model.codebookCoverage.holeFraction);
fprintf('Fixed block: %d slots (%.1f ms); candidate slots=%d; opportunity max-flow=%d/%d\n', ...
    p.time.blockSlots,1e3*p.time.blockSlots*p.time.slotDurationS,model.design.nEvents, ...
    model.problem.precheck.maxFlow,p.system.K);
fprintf('Service model: %s. %s\n',model.design.serviceModel,model.design.guarantee);
if model.problem.precheck.forcedZeroFairness
    fprintf('Precheck: baseline O2 optimal fairness is forced to zero by serviceability.\n');
    fprintf('Users with no positive-service resource: %s\n', ...
        mat2str(model.problem.precheck.neverServiceableUsers.'));
end
values = model.sinr.gammaDb(model.sinr.active);
if isempty(values)
    fprintf('No active data transmission: inspect geometry/coverage/overheads.\n');
else
    fprintf('Example active SINR [min, median, max] = [%.2f, %.2f, %.2f] dB\n', ...
        min(values),median(values),max(values));
end
fprintf('Problem formed, unsolved: %d binary variables + s; example design fairness=%.6g.\n', ...
    numel(model.xExample),model.exampleService.fairness);
fprintf('Stage-2 template fairness floor from feasibility witness: %.6g (not optimized).\n', ...
    model.problem.stage2Example.s0);
fprintf('Tangent/chord built (%s); uniform proxy-optimum fairness-gap bound <= %.6g.\n', ...
    model.surrogate.referenceMode,model.surrogate.error.optimalFairnessGapBound);
if p.method.enabled
    model.method = leo_solve_schedule(model.problem,model.surrogate,p.method,model.xExample);
end
if p.exhaustive.enabled
    model.exhaustive = leo_exhaustive_search(model.problem,p.exhaustive);
    % 问题模板的 solved 字段不冒充求解结果；结果统一保存在 model.exhaustive。
end
end
