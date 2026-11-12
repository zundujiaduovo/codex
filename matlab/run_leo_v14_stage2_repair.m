function [control,files]=run_leo_v14_stage2_repair(source,directory,render)
% 复用已保存的第一阶段；旧策略/修复策略用同门槛、同初值、同种子单独重跑阶段2。
if nargin<3, render=true; end
report=leo_v12_load_report(source); assert(isfield(report.options.method,'coordination'),'A V14 source report is required.');
if ~exist(directory,'dir'), mkdir(directory); end
path=fullfile(directory,'stage2_repair.mat'); files={};
c=leo_v14_coordination_options(report.options.method.coordination);
signature=struct('coordination',c,'method',report.options.method,'methods',{report.options.methods},'seeds',report.options.seeds,'starts',{{}});
for j=1:numel(report.records)
    if strcmp(report.records(j).status,'completed')
        signature.starts{end+1}=struct('method',report.records(j).method,'seed',report.records(j).seed,'x',report.solutions{j}.stage1.x);
    end
end
if exist(path,'file')==2
    loaded=load(path,'control'); control=loaded.control;
    assert(isequaln(control.signature,signature) && isequaln(control.problemData,report.problemData),'Repair protocol changed; use another repair output directory.');
else
    d=report.problemData; problem=struct('data',d,'evaluate',@(x)leo_evaluate_service(d,x));
    cache=leo_prepare_upper_bounds(d); rows=struct([]); runs={}; sourceRows=struct([]); roundRows=struct([]);
    for j=1:numel(report.records)
        record=report.records(j); id=leo_method_id(record.method);
        if ~strcmp(record.status,'completed') || ~any(strcmp(id,{'sb_v12_lexicographic','local_v12_lexicographic','proxy_tabu'})), continue; end
        initialX=report.solutions{j}.stage1.x; initial=problem.evaluate(initialX); floorValue=initial.fairness;
        start=struct('x',initialX,'service',initial);
        for repaired=[false,true]
            o=report.options.method; o.coordination=c; o.coordination.stage2Floor=floorValue;
            o.coordination.stage2TrustPaths=repaired; o.coordination.stage2StallExpand=repaired;
            o.verbose=true; o.innerSolver='sb';
            if strcmp(id,'local_v12_lexicographic'), o.innerSolver='local'; end
            if strcmp(id,'proxy_tabu'), o.innerSolver='tabu'; end
            variant='paired_old_policy'; if repaired, variant='paired_trust_repair'; end
            fprintf('\nV14 stage-2 replay: %s / %s, seed %.0f, fixed floor %.9g.\n',leo_method_name(record.method),variant,record.seed,floorValue);
            previous=rng; rng(record.seed,'twister'); budget=struct('timer',tic,'seconds',Inf,'iterationOnly',true);
            try
                proxy=leo_v12_build_service_surrogates(problem,'current_schedule',initialX);
                stage=leo_v14_run_price_phase(problem,proxy,cache,'throughput',start,o,budget);
                seconds=toc(budget.timer);
            catch err
                rng(previous); rethrow(err);
            end
            rng(previous); exact=problem.evaluate(stage.x);
            assert(all(exact.demandRatio>=floorValue) && exact.totalBits>=initial.totalBits);
            row=struct('method',leo_method_name(record.method),'variant',variant,'seed',record.seed,'floor',floorValue, ...
                'initialFairness',initial.fairness,'initialTotalBits',initial.totalBits, ...
                'previousSavedFinalBits',record.totalBits,'finalFairness',exact.fairness,'finalTotalBits',exact.totalBits, ...
                'gainBits',exact.totalBits-initial.totalBits,'seconds',seconds,'preserved',true, ...
                'initialMask',char(double(initialX(:).')+'0'));
            rows=leo_append_struct(rows,row); runs{end+1}=struct('method',row.method,'variant',variant,'seed',record.seed,'initialX',initialX,'stage',stage);
            for e=1:numel(stage.sourceEvidence)
                entry=stage.sourceEvidence(e); entry.method=row.method; entry.variant=variant; entry.seed=record.seed;
                sourceRows=leo_append_struct(sourceRows,entry);
            end
            h=stage.history;
            for k=1:stage.rounds
                entry=struct('method',row.method,'variant',variant,'seed',record.seed,'round',k,'fairness',h.savedFairness(k),'totalBits',h.savedTotalBits(k));
                for name={'novelCandidates','trustPathCandidates','trustBridgeCandidates','trustRejectedCandidates', ...
                        'trustEscape','stage2StagnantRounds','trustRadius','jointAccepted','lambdaSum'}
                    entry.(name{1})=h.(name{1})(k);
                end
                roundRows=leo_append_struct(roundRows,entry);
            end
            fprintf('STAGE2 %s / %s: V %.6g -> %.6g Mbit, gain %.6g Mbit, time %.3f s, floor preserved.\n', ...
                row.method,variant,initial.totalBits/1e6,exact.totalBits/1e6,row.gainBits/1e6,seconds);
        end
    end
    control=struct('signature',signature,'problemData',d,'rows',rows,'runs',{runs},'sourceEvidence',sourceRows,'rounds',roundRows, ...
        'scope','Within each method: identical saved stage-1 schedule, identical floor and reset search seed; no stage-1 rerun. Floors differ across methods. Paired old-policy replay differs from historical continuation because RNG is reset.');
    save(path,'control','-v7');
end
leo_write_struct_csv(fullfile(directory,'stage2_repair_runs.csv'),control.rows);
leo_write_struct_csv(fullfile(directory,'stage2_repair_sources.csv'),control.sourceEvidence);
leo_write_struct_csv(fullfile(directory,'stage2_repair_rounds.csv'),control.rounds);
methods={'SB','Local','Proxy+Tabu'};
for j=1:numel(methods)
    p(j)=leo_v14_panel([methods{j},': own fixed floor, shared start'],'Stage-2 elapsed seconds','Gain over stage-1 service (Mbit)'); %#ok<AGROW>
    for k=1:numel(control.runs)
        run=control.runs{k}; if ~strcmp(run.method,methods{j}) || run.seed~=report.options.seeds(1), continue; end
        h=run.stage.history; initial=run.stage.initialService.totalBits;
        p(j)=leo_v14_series(p(j),run.variant,[0,h.elapsedSeconds],[0,(h.savedTotalBits-initial)/1e6]);
    end
end
spec=struct('name','v14_stage2_trust_repair','title','V14 phase-2 policy repair | paired within method | saved stage 1 retained','rows',1,'cols',3,'panels',p);
files=leo_v14_save_specs(spec,directory,'stage2_repair_specs',render);
end
