function [control,files]=run_leo_v14_common_floor(source,directory,render,s0)
% 同一原始可行日程、同一公平门槛、同一搜索种子，单独比较第二阶段。
if nargin<3, render=true; end
if nargin<4, s0=2.60; end
report=leo_v12_load_report(source); if ~exist(directory,'dir'), mkdir(directory); end
assert(isfield(report.options.method,'coordination'),'Use a completed V14 report for this control.');
path=fullfile(directory,'common_floor.mat'); files={}; protocol=struct('floor',s0,'method',report.options.method,'seeds',report.options.seeds);
if exist(path,'file')==2
 saved=load(path,'control'); control=saved.control;
 assert(isequaln(control.protocol,protocol) && isequaln(control.problemData,report.problemData));
else
 d=report.problemData; problem=struct('data',d,'evaluate',@(x)leo_evaluate_service(d,x));
 cache=leo_prepare_upper_bounds(d); rows=struct([]); runs={}; witnesses={};
 for seed=report.options.seeds
    witness=[]; initial=[];
    for j=1:numel(report.records)
        if report.records(j).seed~=seed || ~strcmp(report.records(j).status,'completed'), continue; end
        candidate=report.solutions{j}.stage1; exact=problem.evaluate(candidate.x);
        if all(exact.demandRatio>=s0) && (isempty(initial) || exact.totalBits>initial.totalBits)
            witness=candidate.x; initial=exact;
        end
    end
    if isempty(witness)
        for name=report.options.methods
            rows=leo_append_struct(rows,struct('method',leo_method_name(name{1}),'seed',seed,'floor',s0, ...
             'initialFairness',NaN,'initialTotalBits',NaN,'finalFairness',NaN,'finalTotalBits',NaN,'seconds',NaN, ...
             'status','not_run_no_common_feasible_start'));
        end
        continue;
    end
    witnesses{end+1}=struct('seed',seed,'x',witness,'service',initial);
    start=struct('x',witness,'service',initial);
    for name=report.options.methods
        o=report.options.method; o.seed=seed; o.verbose=false; o.coordination.stage2Floor=s0;
        old=rng; rng(seed,'twister'); budget=struct('timer',tic,'seconds',Inf,'iterationOnly',true);
        id=leo_method_id(name{1});
        if any(strcmp(id,{'original_tabu','original_greedy'}))
            kind='tabu'; if strcmp(id,'original_greedy'), kind='greedy'; end
            stage=leo_v14_original_stage2(problem,start,kind,s0,o,budget);
        else
            o.innerSolver='sb'; if strcmp(id,'local_v12_lexicographic'), o.innerSolver='local'; end
            if strcmp(id,'proxy_tabu'), o.innerSolver='tabu'; end
            % The same initial tangent is constructed independently and charged to every method.
            proxy=leo_v12_build_service_surrogates(problem,'current_schedule',witness);
            stage=leo_v14_run_price_phase(problem,proxy,cache,'throughput',start,o,budget);
        end
        seconds=toc(budget.timer); rng(old); exact=problem.evaluate(stage.x); assert(all(exact.demandRatio>=s0));
        rows=leo_append_struct(rows,struct('method',leo_method_name(name{1}),'seed',seed,'floor',s0, ...
          'initialFairness',initial.fairness,'initialTotalBits',initial.totalBits,'finalFairness',exact.fairness, ...
          'finalTotalBits',exact.totalBits,'seconds',seconds,'status','completed'));
        runs{end+1}=struct('method',leo_method_name(name{1}),'seed',seed,'initialX',witness,'stage',stage);
    end
 end
 upper=leo_v14_floor_bound(report,s0); coupled=leo_v14_coupled_bound(report,'throughput',s0);
 control=struct('protocol',protocol,'problemData',d,'rows',rows,'runs',{runs},'witnesses',{witnesses}, ...
    'upperBits',min(upper.upperBits,coupled.upper),'floorBound',upper,'coupledBound',coupled);
 save(path,'control','-v7');
end
leo_write_struct_csv(fullfile(directory,'common_floor_runs.csv'),control.rows);
p=leo_v14_panel(sprintf('Stage 2 only: same start, s0=%.4g',s0),'Stage-2 elapsed seconds','Mbit/period');
for j=1:numel(control.runs)
    run=control.runs{j}; if run.seed~=report.options.seeds(1), continue; end
    h=run.stage.history; p=leo_v14_series(p,run.method,h.elapsedSeconds,h.savedTotalBits/1e6);
end
p.reference=control.upperBits/1e6; p.referenceLabel='Conditional valid upper (attainability unproved)';
spec=struct('name','v17_common_floor_throughput','title','V17 fixed-floor stage-2 control (fairness promotion disabled) | shared initialization saved in MAT','rows',1,'cols',1,'panels',p);
files=leo_v14_save_specs(spec,directory,'common_floor_specs',render);
end
