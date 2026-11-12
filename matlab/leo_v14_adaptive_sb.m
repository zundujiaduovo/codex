function r=leo_v14_adaptive_sb(q,o,seeds,budget)
% 自适应bSB：固定QUBO内逐轨迹按合法候选停滞重启。不是EC-bSB。
c=o.coordination; ising=leo_qubo_to_ising(q); N=q.nBits; R=o.sbTrajectories;
scale=max([sum(abs(ising.J),2)+abs(ising.h);realmin]); J=ising.J/scale; h=ising.h/scale;
p=.05*(2*rand(N,R)-1); v=.05*(2*rand(N,R)-1);
n=min(R,size(seeds,2)); p(:,1:n)=(2*seeds(:,1:n)-1).*(.05+.02*rand(N,n));
age=zeros(1,R); last=zeros(1,R); restarts=zeros(1,R); active=true(1,R);
spin=ones(N,R); spin(p<0)=-1; bestSpin=spin; energy=discrete(spin);
legal=false(q.nUsers,R); legalScore=-Inf(1,R); forceTerms=0; trajectorySteps=0;
history=struct('step',0,'minimum',min(energy),'median',median(energy),'maximum',max(energy));
energyByTrajectory=energy(:);
completed=0;
for k=1:o.sbSteps
    ids=find(active); if isempty(ids) || leo_budget_expired(budget), break; end
    age(ids)=age(ids)+1; pump=min(1,age(ids)/c.sbMinSteps);
    force=bsxfun(@times,p(:,ids),pump-1)-o.sbCoupling*bsxfun(@plus,J*p(:,ids),h);
    v(:,ids)=v(:,ids)+o.sbTimeStep*force; p(:,ids)=p(:,ids)+o.sbTimeStep*v(:,ids);
    pp=p(:,ids); vv=v(:,ids); wall=abs(pp)>1; pp(wall)=sign(pp(wall)); vv(wall)=0;
    p(:,ids)=pp; v(:,ids)=vv; completed=k;
    trajectorySteps=trajectorySteps+numel(ids); forceTerms=forceTerms+N^2*numel(ids);
    if mod(k,o.sbCheckpoint)~=0 && k~=o.sbSteps, continue; end
    s=ones(N,numel(ids)); s(p(:,ids)<0)=-1; e=discrete(s); better=e<energy(ids);
    bestSpin(:,ids(better))=s(:,better); energy(ids(better))=e(better);
    for j=1:numel(ids)
        a=ids(j); x=leo_repair_group(q,s(1:q.nUsers,j)>0); score=proxy(x);
        if score>legalScore(a)+1e-12*max(1,abs(score))
            legal(:,a)=x; legalScore(a)=score; last(a)=age(a);
        end
        if age(a)>=c.sbMinSteps && age(a)-last(a)>=c.sbStagnationSteps
            if restarts(a)<c.sbMaxRestarts
                restarts(a)=restarts(a)+1; p(:,a)=.05*(2*rand(N,1)-1); v(:,a)=.05*(2*rand(N,1)-1);
                if mod(restarts(a),2)==0, p(:,a)=(2*leo_encode_group_bits(q,legal(:,a))-1).*(.05+.02*rand(N,1)); end
                age(a)=0; last(a)=0;
            else, active(a)=false; end
        end
    end
    history.step(end+1)=k; history.minimum(end+1)=min(energy);
    history.median(end+1)=median(energy); history.maximum(end+1)=max(energy);
    energyByTrajectory(:,end+1)=energy(:);
end
r=struct('bits',(bestSpin+1)/2,'legalGroups',legal,'energy',energy,'steps',completed, ...
    'energyScale',scale,'history',history,'trajectories',R,'trajectorySteps',trajectorySteps, ...
    'denseTerms',forceTerms,'restarts',sum(restarts),'stoppedByTime',leo_budget_expired(budget), ...
    'energyByTrajectory',energyByTrajectory);
    function e=discrete(s)
        e=ising.constant+ising.h.'*s+sum(s.*(ising.J*s),1)/2;
    end
    function value=proxy(x)
        z=double(x); value=q.A.'*z-z.'*q.B*z/2;
    end
end
