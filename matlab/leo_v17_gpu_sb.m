function r=leo_v17_gpu_sb(q,o,seeds,kernel,budget,useGpu)
% All trajectories share one GPU matrix. CPU double scores govern acceptance.
% useGpu=false runs identical arithmetic/initialization on CPU for paired tests.
if nargin<5, budget=[]; end
if nargin<6, useGpu=true; end
e=leo_v17_execution_options(); if isfield(o,'execution'), e=leo_v17_execution_options(o.execution); end
adaptive=strcmp(kernel,'adaptive'); assert(adaptive || strcmp(kernel,'fixed'));
c=o.coordination; ising=leo_qubo_to_ising(q); N=q.nBits; R=o.sbTrajectories;
assert(size(seeds,1)==N && all(seeds(:)==0 | seeds(:)==1));
scale=max([sum(abs(ising.J),2)+abs(ising.h);realmin]);
toDevice=@(a)cast(a,e.precision); toHost=@(a)a;
if useGpu, toDevice=@(a)gpuArray(cast(a,e.precision)); toHost=@gather; end
% Draw on the CPU so GPU and vectorized CPU controls have the same initial states.
initialP=.05*(2*rand(N,R)-1); initialV=.05*(2*rand(N,R)-1);
n=min(R,size(seeds,2)); initialP(:,1:n)=(2*seeds(:,1:n)-1).*(.05+.02*rand(N,n));
p=toDevice(initialP); v=toDevice(initialV); J=toDevice(ising.J/scale); h=toDevice(ising.h/scale);
pumpTable=toDevice(min(1,(0:o.sbSteps)/c.sbMinSteps));
spin=2*double(initialP>=0)-1; bestSpin=spin; energy=discrete(spin);
age=zeros(1,R); last=zeros(1,R); restarts=zeros(1,R); active=true(1,R);
legal=false(q.nUsers,R); legalScore=-Inf(1,R); repairCache=containers.Map('KeyType','char','ValueType','any');
uniqueRepairs=0; repairCacheHits=0; completed=0; trajectorySteps=0;
history=struct('step',0,'minimum',min(energy),'median',median(energy),'maximum',max(energy));
energyByTrajectory=energy(:);
for k=1:o.sbSteps
    ids=find(active); if isempty(ids) || leo_budget_expired(budget), break; end
    age(ids)=age(ids)+1;
    pump=k/o.sbSteps; if adaptive, pump=pumpTable(age(ids)+1); end
    pp=p(:,ids); vv=v(:,ids);
    force=bsxfun(@times,pp,pump-1)-o.sbCoupling*bsxfun(@plus,J*pp,h);
    vv=vv+o.sbTimeStep*force; pp=pp+o.sbTimeStep*vv;
    % Elementwise clipping avoids host synchronization for logical GPU indexing.
    wall=abs(pp)>1; vv=vv.*cast(~wall,'like',vv); pp=min(1,max(-1,pp));
    p(:,ids)=pp; v(:,ids)=vv; completed=k; trajectorySteps=trajectorySteps+numel(ids);
    if mod(k,o.sbCheckpoint)~=0 && k~=o.sbSteps, continue; end
    % Transfer only binary states at checkpoints; continuous state stays on GPU.
    s=2*double(toHost(p(:,ids)>=0))-1; values=discrete(s); better=values<energy(ids);
    bestSpin(:,ids(better))=s(:,better); energy(ids(better))=values(better);
    if adaptive
        for j=1:numel(ids)
            a=ids(j); raw=s(1:q.nUsers,j)>0; key=char(double(raw.')+'0');
            if isKey(repairCache,key)
                cached=repairCache(key); x=cached.x; score=cached.score; repairCacheHits=repairCacheHits+1;
            else
                x=leo_repair_group(q,raw); z=double(x); score=q.A.'*z-z.'*q.B*z/2;
                repairCache(key)=struct('x',x,'score',score); uniqueRepairs=uniqueRepairs+1;
            end
            if score>legalScore(a)+1e-12*max(1,abs(score)), legal(:,a)=x; legalScore(a)=score; last(a)=age(a); end
            if age(a)>=c.sbMinSteps && age(a)-last(a)>=c.sbStagnationSteps
                if restarts(a)<c.sbMaxRestarts
                    restarts(a)=restarts(a)+1; newP=.05*(2*rand(N,1)-1); newV=.05*(2*rand(N,1)-1);
                    if mod(restarts(a),2)==0, newP=(2*leo_encode_group_bits(q,legal(:,a))-1).*(.05+.02*rand(N,1)); end
                    p(:,a)=toDevice(newP); v(:,a)=toDevice(newV); age(a)=0; last(a)=0;
                else, active(a)=false; end
            end
        end
    end
    history.step(end+1)=k; history.minimum(end+1)=min(energy);
    history.median(end+1)=median(energy); history.maximum(end+1)=max(energy);
    energyByTrajectory(:,end+1)=energy(:);
end
if useGpu, wait(gpuDevice()); end
backend='cpu_vectorized_reference'; if useGpu, backend='gpuArray'; end
r=struct('bits',(bestSpin+1)/2,'energy',energy,'steps',completed,'energyScale',scale, ...
    'history',history,'energyByTrajectory',energyByTrajectory,'trajectories',R, ...
    'trajectorySteps',trajectorySteps,'denseTerms',N^2*trajectorySteps,'restarts',sum(restarts), ...
    'uniqueRepairs',uniqueRepairs,'repairCacheHits',repairCacheHits,'stoppedByTime',leo_budget_expired(budget), ...
    'parallelWorkers',0,'parallelTasks',0,'executionBackend',backend,'dynamicsPrecision',e.precision, ...
    'gpuTrajectorySteps',double(useGpu)*trajectorySteps);
if adaptive, r.legalGroups=legal; end
    function value=discrete(s)
        value=ising.constant+ising.h.'*s+sum(s.*(ising.J*s),1)/2;
    end
end
