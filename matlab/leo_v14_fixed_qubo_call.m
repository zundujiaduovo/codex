function r=leo_v14_fixed_qubo_call(q,old,o,solver,seed)
% 不读取物理原目标、不刷新代理、不改变Q；同一QUBO四内核对照。
previous=rng; cleanup=onCleanup(@()rng(previous)); %#ok<NASGU>
rng(seed,'twister'); budget=struct('timer',tic,'seconds',Inf,'iterationOnly',true); raw=old;
steps=0; restarts=0; terms=0; encodedLegal=[]; extraGroups=[];
if any(strcmp(solver,{'SB adaptive','SB fixed'}))
    seeds=[leo_encode_group_bits(q,old),leo_encode_group_bits(q,false(q.nUsers,1))];
    if strcmp(solver,'SB adaptive')
        sb=leo_v14_adaptive_sb(q,o,seeds,budget); terms=sb.denseTerms; restarts=sb.restarts;
    else
        sb=leo_v8_ballistic_sb(leo_qubo_to_ising(q),o,seeds,budget); terms=q.nBits^2*sb.steps*o.sbTrajectories;
    end
    raw=logical(sb.bits(1:q.nUsers,:)); steps=sb.steps;
    if isfield(sb,'legalGroups'), extraGroups=sb.legalGroups; end
    for j=1:size(raw,2)
        ids=find(raw(:,j)); valid=numel(ids)<=q.maxStreams && numel(unique(q.beamIndex(ids)))==numel(ids);
        if q.capacityIncluded, valid=valid && sum(raw(:,j))+q.slackWeights.'*sb.bits(q.nUsers+1:end,j)==q.maxStreams; end
        encodedLegal(end+1)=valid; %#ok<AGROW>
    end
elseif strcmp(solver,'Local')
    raw=[old,false(q.nUsers,1)];
    for j=1:o.localRestarts
        raw(:,end+1)=leo_repair_group(q,rand(q.nUsers,1)<.5); %#ok<AGROW>
    end
elseif strcmp(solver,'Proxy+Tabu')
    search=leo_proxy_tabu_group(q,old,o,budget); raw=search.x;
else, error('leo:fixedQuboSolver','Unknown fixed QUBO solver.'); end
best=old; bestScore=score(old); rawScore=zeros(1,size(raw,2)); repaired=rawScore; polished=rawScore; legal=rawScore;
for j=1:size(raw,2)
    x=raw(:,j); ids=find(x); legal(j)=numel(ids)<=q.maxStreams && numel(unique(q.beamIndex(ids)))==numel(ids);
    fixed=leo_repair_group(q,x); finished=leo_polish_group(q,fixed,o.polishMoves);
    rawScore(j)=score(x); repaired(j)=score(fixed); polished(j)=score(finished);
    if polished(j)>bestScore, best=finished; bestScore=polished(j); end
end
for j=1:size(extraGroups,2)
    x=leo_polish_group(q,extraGroups(:,j),o.polishMoves);
    if score(x)>bestScore, best=x; bestScore=score(x); end
end
encodedFraction=NaN; if ~isempty(encodedLegal), encodedFraction=mean(encodedLegal); end
r=struct('solver',solver,'seed',seed,'proxyScore',bestScore,'rawScore',max(rawScore), ...
 'repairedScore',max(repaired),'polishedScore',max(polished),'repairLoss',mean(max(0,rawScore-repaired)), ...
 'polishGain',mean(polished-repaired),'rawLegalFraction',mean(legal),'rawEncodedLegalFraction',encodedFraction,'seconds',toc(budget.timer), ...
 'integrationSteps',steps,'sbRestarts',restarts,'denseTerms',terms,'selectedMask',char(double(best.')+'0'));
    function value=score(x)
        z=double(x); value=q.A.'*z-z.'*q.B*z/2;
    end
end
