function r=leo_v17_fairness_escape(problem,start,o,attempt,budget)
% Shared ORIGINAL-objective rescue, explicitly charged separately from the kernel.
% A perturbed trajectory may retreat; the saved lexicographic incumbent cannot.
p=o.searchPolicy; d=problem.data; r=struct('x',start.x,'service',start.service,'evaluations',0,'rounds',0);
timer=tic; current=start; tabu=zeros(d.shape); walks=0;
for k=1:p.escapeRounds
    if leo_budget_expired(budget), break; end
    if k==1 || mod(k-1,12)==0
        x=r.x; [~,order]=sort(r.service.demandRatio); weak=order(1:min(8,numel(order)));
        blocks=randperm(d.shape(2),min(p.escapeBlocks,d.shape(2)));
        for m=blocks
            present=find(x(:,m));
            if ~isempty(present)
                removed=present(randperm(numel(present),min(1+mod(attempt,3),numel(present)))); x(removed,m)=false;
            end
            priority=[weak(randperm(numel(weak)));randperm(d.shape(1)).'];
            for i=priority.'
                if ~d.available(i,m) || x(i,m) || any(d.beamIndex(x(:,m),m)==d.beamIndex(i,m)), continue; end
                x(i,m)=true;
                if sum(x(:,m))>=d.maxStreams, break; end
            end
        end
        current=struct('x',x,'service',problem.evaluate(x)); r.evaluations=r.evaluations+1; walks=walks+1; tabu(:)=0;
        if leo_service_is_better(current.service,r.service,'fairness',0), r.x=current.x; r.service=current.service; end
    end
    pool=leo_original_neighbors(problem,current.x,current.service,p.escapeCandidates,k+attempt*101,budget,true);
    r.evaluations=r.evaluations+numel(pool); at=0;
    for j=1:numel(pool)
        aspiration=leo_service_is_better(pool(j).service,r.service,'fairness',0);
        if any(tabu(pool(j).changed)>k) && ~aspiration, continue; end
        if at==0 || leo_service_is_better(pool(j).service,pool(at).service,'fairness',0), at=j; end
    end
    if at>0
        current=pool(at); current.service=problem.evaluate(current.x); r.evaluations=r.evaluations+1;
        tabu(current.changed)=k+5+mod(attempt,4);
        if leo_service_is_better(current.service,r.service,'fairness',0), r.x=current.x; r.service=current.service; end
    end
    r.rounds=k;
end
r.service=problem.evaluate(r.x); r.evaluations=r.evaluations+1;
r.event=struct('attempt',attempt,'rounds',r.rounds,'walks',walks,'evaluations',r.evaluations, ...
    'seconds',toc(timer),'beforeFairness',start.service.fairness,'afterFairness',r.service.fairness, ...
    'gain',r.service.fairness-start.service.fairness,'scope','Shared original-model fairness rescue; not SB/QUBO work.');
end
