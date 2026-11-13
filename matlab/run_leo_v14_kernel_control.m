function [control,files]=run_leo_v14_kernel_control(source,directory,render,seeds)
% 固定完整块候选域、Q矩阵、参考点和价格，独立比较四种内核。
if nargin<3, render=true; end
report=leo_v12_load_report(source);
assert(isfield(report.options.method,'coordination'),'Use a completed V14 report for this control.');
if nargin<4, seeds=report.options.seeds(1)+(0:4)*104729; end
if ~exist(directory,'dir'), mkdir(directory); end
options=report.options.method; options.coordination.adaptivePenalty=false;
protocol=struct('seeds',seeds,'method',options,'resources',[1,ceil(report.problemData.shape(2)/2),report.problemData.shape(2)]);
path=fullfile(directory,'fixed_qubo_control.mat'); files={};
if exist(path,'file')==2
 saved=load(path,'control'); control=saved.control;
 assert(isequaln(control.protocol,protocol) && isequaln(control.problemData,report.problemData));
else
 d=report.problemData; ids=cellfun(@leo_method_id,{report.records.method},'UniformOutput',false);
 at=find(strcmp(ids,'sb_v12_lexicographic') & strcmp({report.records.status},'completed'),1); assert(~isempty(at),'A completed SB run is required.');
 reference=report.solutions{at}; cases={}; runs=struct([]); caseId=0; solvers={'SB fixed','SB adaptive','SB adaptive serial','Local','Proxy+Tabu'};
 for phase=1:2
    stage=reference.(sprintf('stage%d',phase));
    label='fairness'; floorValue=0; if phase==2, label='throughput'; floorValue=reference.fairnessFloor; end
    w=stage.lambda./d.qosTargetBits; if phase==2, w=w+1/d.referenceBits; end
    for m=unique(protocol.resources)
        q=leo_build_resource_qubo(d,stage.proxy.lower,m,w,options); q=leo_v14_encode_qubo(q,options.penaltyFactor);
        old=stage.x(q.userIds,m); caseId=caseId+1;
        cases{caseId}=struct('id',caseId,'resource',m,'phase',label,'floor',floorValue,'q',q,'old',old, ...
            'weights',w,'referenceW',stage.proxy.referenceW,'referenceMethod','SB final phase proxy and prices', ...
            'scope','Full physical block domain; identical immutable Q for every solver/seed; no outer recovery or original rescoring.');
        for s=1:numel(seeds)
            order=mod((0:numel(solvers)-1)+s-1,numel(solvers))+1;
            for index=order
                row=leo_v14_fixed_qubo_call(q,old,options,solvers{index},seeds(s)); row.caseId=caseId;
                runs=leo_append_struct(runs,row);
            end
        end
    end
 end
 references=cell(size(cases));
 for k=1:numel(cases)
    indices=find([runs.caseId]==k); [~,atBest]=max([runs(indices).proxyScore]);
    witness=runs(indices(atBest)).selectedMask.'=='1';
    references{k}=leo_v17_qubo_reference(cases{k}.q,witness,5000);
    for index=indices
        runs(index).referenceLower=references{k}.lower; runs(index).referenceUpper=references{k}.upper;
        runs(index).proxyGapUpper=max(0,references{k}.upper-runs(index).proxyScore);
        runs(index).referenceClosed=references{k}.closed;
    end
    fprintf('V17 frozen QUBO %d: optimum in [%.9g, %.9g], nodes=%d. Reference work excluded from solver times.\n', ...
        k,references{k}.lower,references{k}.upper,references{k}.nodes);
 end
 control=struct('protocol',protocol,'problemData',d,'cases',{cases},'runs',runs,'references',{references});
 save(path,'control','-v7');
end
leo_write_struct_csv(fullfile(directory,'fixed_qubo_runs.csv'),control.runs);
titles={'Legal proxy score','Configured call time','Raw output feasibility','Repair score loss','Polish score gain','SB trajectory restarts'};
fields={'proxyScore','seconds','rawLegalFraction','repairLoss','polishGain','sbRestarts'};
units={'Proxy score','Seconds','Fraction','Proxy score','Proxy score','Count'};
labels=cellfun(@(x)sprintf('%s/b%d',x.phase,x.resource),control.cases,'UniformOutput',false);
solvers={'SB fixed','SB adaptive','SB adaptive serial','Local','Proxy+Tabu'};
for j=1:6
    p(j)=leo_v14_panel(titles{j},'Identical frozen QUBO case',units{j},'categorical_line',labels); %#ok<AGROW>
    for solver=solvers
        y=NaN(1,numel(labels));
        for k=1:numel(labels)
            rows=control.runs([control.runs.caseId]==k & strcmp({control.runs.solver},solver{1}));
            y(k)=median([rows.(fields{j})]);
        end
        p(j)=leo_v14_series(p(j),solver{1},1:numel(labels),y);
    end
end
spec=struct('name','v17_fixed_qubo_kernels','title','V17 fixed QUBO | paired seeds | serial/parallel use identical 64 trajectories','rows',2,'cols',3,'panels',p);
files=leo_v14_save_specs(spec,directory,'fixed_qubo_specs',render);
quality=leo_v14_panel('Certified proxy objective gap','Frozen QUBO case','Upper minus returned feasible score','categorical_line',labels);
for solver=solvers
    values=NaN(1,numel(labels));
    for k=1:numel(labels)
        rows=control.runs([control.runs.caseId]==k & strcmp({control.runs.solver},solver{1}));
        values(k)=median([rows.proxyGapUpper]);
    end
    quality=leo_v14_series(quality,solver{1},1:numel(labels),values);
end
spec=struct('name','v17_qubo_quality_gaps','title','V17 full-block proxy certificates; original-model optimality is separate','rows',1,'cols',1,'panels',quality);
files=[files,leo_v14_save_specs(spec,directory,'qubo_quality_specs',render)];
end
