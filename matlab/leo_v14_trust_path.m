function [x,path]=leo_v14_trust_path(q,center,target,radius,maxMoves)
% 在可信域内部构造合法add/drop/swap路径，保留每一步。
% target为空：单调代理改进；有target：朝该提案走，可保留补偿用的暂时退步。
x=logical(center(:)); path=x; directed=~isempty(target);
if directed, target=logical(target(:)); end
for step=1:maxMoves
    selected=find(x); absent=find(~x); marginal=q.A-q.B*double(x);
    conflict=bsxfun(@eq,q.beamIndex(absent),q.beamIndex(selected).'); count=sum(conflict,2);
    additions=marginal(absent); additions(count>0 | numel(selected)>=q.maxStreams)=-Inf;
    swaps=bsxfun(@minus,marginal(absent),marginal(selected).')+q.B(absent,selected);
    allowed=bsxfun(@or,count==0,bsxfun(@and,count==1,conflict)); swaps(~allowed)=-Inf;
    moves=[additions,swaps].'; gains=[-marginal(selected);moves(:)];
    drops=[selected;repmat([0;selected],numel(absent),1)];
    adds=[zeros(numel(selected),1);kron(absent,ones(numel(selected)+1,1))];
    distance=sum(x~=center); addChange=[0;1-2*double(center)]; dropChange=[0;2*double(center)-1];
    gains(distance+addChange(adds+1)+dropChange(drops+1)>radius)=-Inf;
    if directed
        permitAdd=[true;target]; permitDrop=[true;~target];
        gains(~permitAdd(adds+1) | ~permitDrop(drops+1))=-Inf;
    end
    [gain,at]=max(gains);
    if isempty(gain) || ~isfinite(gain), break; end
    if ~directed && gain<=1e-13*max(1,sum(abs(q.A))), break; end
    if drops(at)>0, x(drops(at))=false; end
    if adds(at)>0, x(adds(at))=true; end
    path(:,end+1)=x; %#ok<AGROW>
end
end
