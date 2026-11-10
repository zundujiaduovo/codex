function audit = run_leo_v11_verify_exports(directory)
%RUN_LEO_V11_VERIFY_EXPORTS 从CSV还原二元日程，用冻结原模型重新计算服务和QoS。
% 不加载搜索轨迹，不运行优化，不使用二次代理。原模型快照须与CSV同目录。
saved=load(fullfile(directory,'original_model.mat'),'originalModel'); data=saved.originalModel.problemData;
runs=read_csv(fullfile(directory,'runs.csv'));
schedule=read_csv(fullfile(directory,'schedules.csv')); users=read_csv(fullfile(directory,'user_service.csv'));
scheduleSeed=str2double(schedule.seed); userSeed=str2double(users.seed);
verified=0; maximumError=0;
for j=1:numel(runs.method)
    if ~strcmp(runs.status{j},'completed'), continue; end
    method=runs.method{j}; seed=str2double(runs.seed{j});
    rows=find(strcmp(schedule.method,method) & scheduleSeed==seed);
    assert(numel(rows)==prod(data.shape),'Missing schedule cells.');
    i=str2double(schedule.user(rows)); m=str2double(schedule.resource(rows));
    assert(all(i>=1 & i<=data.shape(1) & i==fix(i)) && all(m>=1 & m<=data.shape(2) & m==fix(m)));
    positions=sub2ind(data.shape,i,m); assert(numel(unique(positions))==prod(data.shape));
    x=zeros(data.shape); x(positions)=str2double(schedule.selected(rows));
    service=leo_evaluate_service(data,x); % 完整原SINR/log速率/风险余量及二元硬约束复核。
    expected=str2double(runs.totalBits{j}); errorBits=abs(service.totalBits-expected);
    assert(errorBits<=1e-9*max(1,abs(expected)),'Exported score differs from original-model evaluation.');
    full=all(service.userBits>=data.qosTargetBits);
    assert(full==logical(str2double(runs.fullQosFeasible{j})));
    selected=find(strcmp(users.method,method) & userSeed==seed);
    assert(numel(selected)==data.shape(1)); ids=str2double(users.user(selected));
    assert(isequal(sort(ids),(1:data.shape(1)).'));
    values=str2double(users.serviceBits(selected)); targets=str2double(users.targetBits(selected));
    assert(all(abs(values-service.userBits(ids))<=1e-9*max(1,abs(service.userBits(ids)))));
    assert(isequal(targets,data.qosTargetBits(ids)));
    verified=verified+1; maximumError=max(maximumError,errorBits);
end
audit=struct('verifiedRuns',verified,'maxTotalErrorBits',maximumError, ...
    'scope','CSV binary schedules re-evaluated with the frozen ORIGINAL certified-service model; no optimization or quadratic proxy.');
fprintf('PASS: %d exported schedules re-evaluated by the original model; max total error %.9g bit.\n',verified,maximumError);
end
function table=read_csv(path)
fid=fopen(path,'r','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
header=fgetl(fid); assert(ischar(header)); names=strsplit(header,',');
columns=textscan(fid,repmat('%q',1,numel(names)),'Delimiter',',','EndOfLine','\n');
table=struct();
for j=1:numel(names), table.(names{j})=columns{j}; end
end
