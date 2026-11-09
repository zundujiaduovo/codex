function leo_export_certificate_audit(report,directory)
%LEO_EXPORT_CERTIFICATE_AUDIT 公共证书参数及相同日程的新旧公式对照，禁止混作算法提升。
d=report.problemData.design;
if ~strcmp(d.serviceModel,'periodic_multilevel'), return; end
rows=struct([]);
for i=1:report.problemData.shape(1)
 row=struct('user',i,'referenceFade',d.selectedReferenceFade(i),'tilt',d.selectedTilt(i), ...
  'multilevelSelected',d.selectedMultilevel(i),'serviceScale',d.serviceScale(i), ...
  'periodMarginBits',d.serviceMarginBits(i),'riskBudget',d.userRisk(i), ...
  'calibrationOldBits',d.legacyCalibrationBits(i),'calibrationNewBits',d.calibrationBits(i));
 if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
leo_write_struct_csv(fullfile(directory,'certificate_parameters.csv'),rows);
p=report.parameters; p.statistics.serviceModel='periodic_chernoff';
r=leo_build_resources(p); b.available=report.problemData.available; b.index=report.problemData.beamIndex;
c.noiseW=d.noiseW; link.signalW=d.nominalSignalW; link.beamPowerW=d.nominalBeamPowerW;
oldData=report.problemData; oldData.design=leo_prepare_design_service(p,r,b,c,link);
rows=struct([]);
for j=1:numel(report.records)
 if ~strcmp(report.records(j).status,'completed'), continue; end
 old=leo_evaluate_service(oldData,report.solutions{j}.x); new=report.solutions{j}.service;
 row=struct('method',report.records(j).method,'seed',report.records(j).seed, ...
  'oldFairness',old.fairness,'newFairness',new.fairness, ...
  'oldQosRate',mean(old.demandRatio>=1),'newQosRate',mean(new.demandRatio>=1), ...
  'oldTotalBits',old.totalBits,'newTotalBits',new.totalBits);
 if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
leo_write_struct_csv(fullfile(directory,'same_schedule_certificates.csv'),rows);
end
