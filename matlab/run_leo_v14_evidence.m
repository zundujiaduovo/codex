function rows=run_leo_v14_evidence(report,directory)
% 每类实际接受的公平/吞吐增益与成本；不把局部代理差当全局损失。
rows=struct([]); rounds=struct([]);
for j=1:numel(report.records)
 r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
 for phase=1:2
    stage=report.solutions{j}.(sprintf('stage%d',phase));
    if ~isfield(stage,'sourceEvidence'), continue; end
    for k=1:numel(stage.sourceEvidence)
        row=stage.sourceEvidence(k); row.method=leo_method_name(r.method); row.seed=r.seed;
        rows=leo_append_struct(rows,row);
    end
    h=stage.history;
    for k=1:stage.rounds
        row=struct('method',leo_method_name(r.method),'seed',r.seed,'phase',phase,'round',k,'fairness',h.savedFairness(k));
        for name={'lambdaSum','trustRadius','gainPredictionErrors','rankingReversals','jointAccepted','jointFairnessGain', ...
                'jointEvaluations','skippedExtraCalls','sbRestarts','sbTrajectorySteps','denseDynamicsTerms','repairLoss', ...
                'novelCandidates','trustPathCandidates','trustBridgeCandidates','trustRejectedCandidates','trustEscape','stage2StagnantRounds'}
            value=NaN; if isfield(h,name{1}), value=h.(name{1})(k); end
            row.(name{1})=value;
        end
        rounds=leo_append_struct(rounds,row);
    end
 end
end
leo_write_struct_csv(fullfile(directory,'v14_candidate_source_evidence.csv'),rows);
leo_write_struct_csv(fullfile(directory,'v14_coordination_rounds.csv'),rounds);
boundRows=struct([]);
c=report.fairnessCertificate;
if isfield(c,'coupledRelaxation')
    b=c.coupledRelaxation;
    boundRows=leo_append_struct(boundRows,bound_row(b,c.cardinalityRelaxation.upper,c.upper));
end
saved=load(fullfile(directory,'conditional_throughput_bounds.mat'),'cache');
for j=1:numel(saved.cache.bounds)
    t=saved.cache.bounds{j};
    if isfield(t,'coupledRelaxation')
        boundRows=leo_append_struct(boundRows,bound_row(t.coupledRelaxation,t.cardinalityFloorBound.upperBits,t.upperBits));
    end
end
leo_write_struct_csv(fullfile(directory,'v14_bound_components.csv'),boundRows);
end
function row=bound_row(b,previous,merged)
row=struct('phase',b.phase,'floor',b.floor,'previousValidUpper',previous,'coupledDualUpper',b.upper, ...
 'mergedUpper',merged,'variables',b.variables,'constraints',b.constraints,'sharedProducts',b.sharedProducts, ...
 'floorConstraints',b.floorConstraints,'floorMultiplierSum',b.lp.floorMultiplierSum, ...
 'elapsedSeconds',b.elapsedSeconds,'backend',b.lp.backend,'status',b.lp.status);
end
