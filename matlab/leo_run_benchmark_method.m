function result=leo_run_benchmark_method(problem,proxy,provided,name,options)
% V16 five-method dispatcher; all proxy methods share the current outer engine.
name=leo_method_id(name);
if any(strcmp(name,{'sb_v12_lexicographic','local_v12_lexicographic','proxy_tabu'}))
    o=leo_v12_method_options(); fields=fieldnames(o);
    for j=1:numel(fields), if isfield(options,fields{j}), o.(fields{j})=options.(fields{j}); end; end
    for field={'stopping','audit','fastPolish'}
        if isfield(options,field{1}), o.(field{1})=options.(field{1}); end
    end
    [~,extra]=leo_extract_iteration_options(options); fields=fieldnames(extra);
    for j=1:numel(fields), o.(fields{j})=extra.(fields{j}); end
    o.innerSolver='sb';
    if strcmp(name,'local_v12_lexicographic'), o.innerSolver='local'; end
    if strcmp(name,'proxy_tabu'), o.innerSolver='tabu'; end
    o.blockwiseOriginalAccept=true;
    result=leo_v12_solve_schedule(problem,[],o,provided);
    result.usesQuadraticProxy=true; result.usesProvidedSchedule=~isempty(provided);
    result.searchEngine=['V16 coordinated original-service acceptance / ',o.innerSolver];
elseif any(strcmp(name,{'original_tabu','original_greedy'}))
    kind='tabu'; if strcmp(name,'original_greedy'), kind='greedy'; end
    result=leo_solve_original_search(problem,kind,options,provided);
else
    error('leo:v16Method','V16 supports Tabu, SB, Local, Proxy+Tabu and Greedy.');
end
end
