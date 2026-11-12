function specs = leo_build_v12_specs(report,data)
%LEO_BUILD_V12_SPECS 明确区分未封顶公平主指标、固定公平门槛下的吞吐和QoS辅助项。
methods=report.options.methods; seed=report.options.seeds(1); n=numel(methods);
methodNames=cellfun(@leo_method_name,methods,'UniformOutput',false);
release=leo_lexicographic_release(report);
first=NaN(1,n); final=first; before=first; after=first; floors=first; conditional=first;
p=panel('categorical_line',[release.tag,' primary: uncapped minimum cumulative service ratio'],'Method','min_i G_i/q_i (uncapped)'); p.labels=methodNames;
p(2)=panel('categorical_line','Secondary service at each method''s attained floor','Method and attained floor','Mbit/period');
p(3)=panel('line','Primary fairness versus recorded elapsed time','Accounted elapsed time (s)','Uncapped min_i G_i/q_i');
p(4)=panel('line','Total service versus time: fairness phase may reduce sum','Accounted elapsed time (s)','Mbit/period');
p(5)=panel('line','Final per-user cumulative guaranteed-service ratios','User','G_i/q_i (uncapped)');
p(6)=panel('categorical_line','Valid conditional throughput upper bounds at stated floors','Method and attained floor','Mbit/period');
for j=1:n
    index=find(strcmp({report.records.method},methods{j}) & [report.records.seed]==seed,1);
    if isempty(index) || ~strcmp(report.records(index).status,'completed'), continue; end
    r=report.records(index); solution=report.solutions{index};
    first(j)=r.stage1Fairness; final(j)=r.fairness; floors(j)=r.requiredFairnessFloor;
    before(j)=solution.stage1.service.totalBits/1e6; after(j)=r.totalBits/1e6; conditional(j)=r.conditionalThroughputUpperBits/1e6;
    rows=data.progress(strcmp({data.progress.method},methods{j}) & [data.progress.seed]==seed);
    p(3)=series(p(3),methodNames{j},[rows.seconds],[rows.fairness]);
    p(4)=series(p(4),methodNames{j},[rows.seconds],[rows.totalBits]/1e6);
    p(5)=series(p(5),methodNames{j},1:report.problemData.shape(1),solution.service.demandRatio);
end
p(1)=series(p(1),'Attained stage-1 fairness',1:n,first); p(1)=series(p(1),'Final fairness',1:n,final);
p(1).reference=report.fairnessCertificate.upper; p(1).referenceLabel='Certified upper; attainability unproved';
if isfield(report.fairnessCertificate,'cardinalityRelaxation')
    p(1).referenceLabel='Relaxation/refined upper; not an attained optimum';
end
p(2)=series(p(2),'Stage 1 service',1:n,before); p(2)=series(p(2),'Stage 2 service',1:n,after);
labels=cell(1,n); for j=1:n, labels{j}=sprintf('%s (s0=%.5g)',methodNames{j},floors(j)); end
p(2).labels=labels; p(6).labels=labels;
p(6)=series(p(6),'Final original-model service',1:n,after); p(6)=series(p(6),'Conditional upper; attainability unproved',1:n,conditional);
p(5).reference=1; p(5).referenceLabel='QoS demand reference (auxiliary, not fairness cap)';
p(1).note='Uncapped fairness: s=1 is not a stopping target. A certified global interval and attained method fairness are distinct.';
p(2).note='Each method holds its own attained s0. Compare secondary service as the same problem only when the floors are the same.';
p(3).note='Real saved checkpoints. No cap at 1, no fabricated plateau or extension after stopping.';
p(4).note='During stage 1 fairness has priority over total service. Stage 2 preserves the attained stage-1 floor.';
p(5).note='Services are accumulated over all slots before taking user ratios. Instantaneous per-slot fairness is not the objective.';
p(6).note='Conditional original-model sum-service bounds; these are not certificates for the primary max-min objective.';
titleText=sprintf('%s | uncapped max-min first, sum service second | seed %.0f',release.tag,seed);
if any(strcmp(release.tag,{'V13','V14','V15','V16'}))
    pModel=report.parameters;
    titleText=sprintf('%s | K=%d, Na=%d, NB=%d, L=%d | uncapped max-min first, sum second | seed %.0f', ...
        release.tag,pModel.system.K,pModel.array.nElements,pModel.array.nBeams,pModel.system.maxStreams,seed);
end
specs=struct('name',[release.prefix,'_uncapped_lexicographic'],'title',titleText, ...
    'rows',3,'cols',2,'panels',p);
end
function p=panel(kind,titleText,xlabelText,ylabelText)
p=struct('kind',kind,'title',titleText,'xlabel',xlabelText,'ylabel',ylabelText,'labels',{{}}, ...
    'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}}, ...
    'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=series(p,name,x,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]));
end
