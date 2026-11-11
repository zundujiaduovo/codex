function specs = leo_build_v12_diagnostic_specs(report,data)
%LEO_BUILD_V12_DIAGNOSTIC_SPECS 原生外层迭代、原式候选评价和共同质量达标时间。
seed=report.options.seeds(1); methods=report.options.methods;
methodNames=cellfun(@leo_method_name,methods,'UniformOutput',false);
release=leo_lexicographic_release(report);
p=panel('Stage 1: saved uncapped fairness','Native outer iteration (method-specific units)','min_i G_i/q_i');
p(2)=panel('Stage 1: sum service while fairness is prioritized','Native outer iteration (method-specific units)','Mbit/period');
p(3)=panel('Stage 2: fairness retained at each method''s s0','Native outer iteration (method-specific units)','min_i G_i/q_i');
p(4)=panel('Stage 2: sum service at each attained floor','Native outer iteration (method-specific units)','Mbit/period');
q=p; q(1).xlabel='Recorded original candidate scores in this phase'; q(2).xlabel=q(1).xlabel;
q(2).title='Stage 2: sum service versus recorded original candidate scores';
q(3)=panel('Time to a common original-model fairness target','Method','First recorded attainment (s)'); q(3).kind='categorical_line'; q(3).labels=methodNames;
q(4)=panel('Actual end-to-end runtime','Method','Seconds'); q(4).kind='categorical_line'; q(4).labels=methodNames;
for j=1:numel(methods)
    for phase=1:2
        rows=data.iterations(strcmp({data.iterations.method},methods{j}) & [data.iterations.seed]==seed & [data.iterations.phase]==phase);
        p(2*phase-1)=add(p(2*phase-1),methodNames{j},[rows.nativeIteration],[rows.fairness]);
        p(2*phase)=add(p(2*phase),methodNames{j},[rows.nativeIteration],[rows.totalBits]/1e6);
        if phase==1, q(1)=add(q(1),methodNames{j},[rows.recordedOriginalCandidateScores],[rows.fairness]);
        else, q(2)=add(q(2),methodNames{j},[rows.recordedOriginalCandidateScores],[rows.totalBits]/1e6); end
    end
end
for fraction=[.90,.95,.99]
    values=NaN(1,numel(methods));
    for j=1:numel(methods)
        at=find(strcmp({data.targets.method},methods{j}) & [data.targets.seed]==seed & [data.targets.upperBoundFraction]==fraction,1);
        if ~isempty(at), values(j)=data.targets(at).firstRecordedSeconds; end
    end
    q(3)=add(q(3),sprintf('%.0f%% of common fairness upper',100*fraction),1:numel(methods),values);
end
values=NaN(1,numel(methods));
for j=1:numel(methods)
    at=find(strcmp({data.workload.method},methods{j}) & [data.workload.seed]==seed,1);
    if ~isempty(at), values(j)=data.workload(at).endToEndSeconds; end
end
q(4)=add(q(4),'Actual elapsed time',1:numel(methods),values);
for j=1:4
    p(j).note='Actual saved outer history. SB/Local/Proxy+Tabu: price rounds; Tabu: original-model neighborhood rounds; Greedy: accepted additions. Units do not imply equal work. No extension beyond actual stopping.';
    q(j).note='Original candidate counts cover recorded search scores, not all computations. Time targets are identical across methods; missing attainment remains NaN. Phase-2 floors may differ.';
end
specs=struct('name',[release.prefix,'_iteration_convergence'],'title',sprintf('%s native-iteration convergence | units differ by method | seed %.0f',release.tag,seed),'rows',2,'cols',2,'panels',p);
specs(2)=struct('name',[release.prefix,'_workload_quality'],'title',sprintf('%s recorded work and common-quality timing | seed %.0f',release.tag,seed),'rows',2,'cols',2,'panels',q);
end
function p=panel(titleText,xlabelText,ylabelText)
p=struct('kind','line','title',titleText,'xlabel',xlabelText,'ylabel',ylabelText,'labels',{{}}, ...
    'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}}, ...
    'ylim',[],'reference',[],'referenceLabel','','note','');
end
function p=add(p,name,x,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]));
end
