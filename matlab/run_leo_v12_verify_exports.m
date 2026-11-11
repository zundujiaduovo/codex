function audit = run_leo_v12_verify_exports(directory)
%RUN_LEO_V12_VERIFY_EXPORTS 原式还原日程，并检查阶段1公平未在阶段2退回1或降低。
s=load(fullfile(directory,'original_model.mat'),'originalModel'); data=s.originalModel.problemData; assert(leo_is_lexicographic(data));
audit=run_leo_v11_verify_exports(directory);
runs=read_csv(fullfile(directory,'runs.csv')); users=read_csv(fullfile(directory,'user_service.csv'));
primarySchedule=read_csv(fullfile(directory,'stage1_schedules.csv'));
primaryUsers=read_csv(fullfile(directory,'stage1_user_service.csv'));
for j=1:numel(runs.method)
    if ~strcmp(runs.status{j},'completed'), continue; end
    rows=strcmp(users.method,runs.method{j}) & str2double(users.seed)==str2double(runs.seed{j});
    ratios=str2double(users.serviceBits(rows))./str2double(users.targetBits(rows));
    floorValue=str2double(runs.requiredFairnessFloor{j}); stage1=str2double(runs.stage1Fairness{j});
    cells=find(strcmp(primarySchedule.method,runs.method{j}) & str2double(primarySchedule.seed)==str2double(runs.seed{j}));
    assert(numel(cells)==prod(data.shape),'Missing first-stage schedule cells.');
    ids=str2double(primarySchedule.user(cells)); blocks=str2double(primarySchedule.resource(cells));
    positions=sub2ind(data.shape,ids,blocks); assert(numel(unique(positions))==prod(data.shape));
    x=zeros(data.shape); x(positions)=str2double(primarySchedule.selected(cells));
    primary=leo_evaluate_service(data,x);
    assert(primary.fairness==stage1,'Reported stage-1 fairness differs from its original-model schedule.');
    assert(str2double(runs.totalBits{j})>=primary.totalBits,'Stage 2 lost first-stage total service.');
    selected=find(strcmp(primaryUsers.method,runs.method{j}) & str2double(primaryUsers.seed)==str2double(runs.seed{j}));
    assert(numel(selected)==data.shape(1)); ids=str2double(primaryUsers.user(selected));
    assert(isequal(sort(ids),(1:data.shape(1)).'));
    assert(all(abs(str2double(primaryUsers.serviceBits(selected))-primary.userBits(ids))<=1e-9*max(1,primary.userBits(ids))));
    assert(floorValue==stage1 && all(ratios>=floorValue),'Exported V12 stage-2 schedule loses stage-1 fairness.');
    assert(abs(min(ratios)-str2double(runs.fairness{j}))<1e-10*max(1,min(ratios)),'Exported fairness is capped or inconsistent.');
    assert(strcmp(runs.objectiveMode{j},'lexicographic_max_min'));
end
audit.verifiedStage1Runs=audit.verifiedRuns;
summary=read_csv(fullfile(directory,'fairness_certificate_summary.csv'));
certificateSchedule=read_csv(fullfile(directory,'fairness_certificate_schedule.csv'));
assert(numel(certificateSchedule.user)==prod(data.shape));
positions=sub2ind(data.shape,str2double(certificateSchedule.user),str2double(certificateSchedule.resource));
assert(numel(unique(positions))==prod(data.shape));
x=zeros(data.shape); x(positions)=str2double(certificateSchedule.selected);
certificateService=leo_evaluate_service(data,x);
assert(certificateService.fairness==str2double(summary.fairnessLower{1}));
upper=str2double(summary.fairnessUpper{1});
assert(upper>=certificateService.fairness && all(upper>=str2double(runs.fairness(strcmp(runs.status,'completed')))));
audit.verifiedFairnessCertificateLower=certificateService.fairness;
fprintf('PASS: V12 BOTH stages re-evaluated from binary CSV schedules; every attained stage-1 fairness floor preserved; no cap at 1.\n');
fprintf('PASS: independent fairness-certificate incumbent re-evaluated; global upper covers every exported method and certificate incumbent.\n');
end
function table=read_csv(path)
fid=fopen(path,'r','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
names=strsplit(fgetl(fid),','); columns=textscan(fid,repmat('%q',1,numel(names)),'Delimiter',',','EndOfLine','\n');
table=struct(); for j=1:numel(names), table.(names{j})=columns{j}; end
end
