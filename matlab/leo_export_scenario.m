function leo_export_scenario(report,directory)
%LEO_EXPORT_SCENARIO 保存可跨 MATLAB/Octave 核对的整数码本与候选域，不用算法成绩作指纹。
if ~isfield(report,'scenario'), return; end
s=report.scenario; rows=struct([]);
for j=1:numel(s.selectedCandidateIndex)
 row=struct('beam',j,'candidateIndex',s.selectedCandidateIndex(j), ...
  'gridX',s.gridIndex(1,j),'gridY',s.gridIndex(2,j),'phaseIndices',mat2str(s.phaseIndex(:,j).'));
 if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
leo_write_struct_csv(fullfile(directory,'scenario_codebook.csv'),rows);
rows=struct([]);
for i=1:numel(s.userLatDeg)
 row=struct('user',i,'latitudeDeg',s.userLatDeg(i),'longitudeDeg',s.userLonDeg(i));
 if isempty(rows), rows=row; else, rows(end+1,1)=row; end
end
leo_write_struct_csv(fullfile(directory,'scenario_users.csv'),rows);
rows=struct([]); d=report.problemData;
for m=1:d.shape(2)
 for i=1:d.shape(1)
  row=struct('user',i,'resource',m,'available',d.available(i,m),'beam',d.beamIndex(i,m));
  if isempty(rows), rows=row; else, rows(end+1,1)=row; end
 end
end
leo_write_struct_csv(fullfile(directory,'scenario_candidates.csv'),rows);
row=struct('seed',report.parameters.seed,'maxStreams',d.maxStreams, ...
 'availablePairs',nnz(d.available),'totalPairs',numel(d.available),'selectionRule',s.selectionRule);
leo_write_struct_csv(fullfile(directory,'scenario_summary.csv'),row);
end
