function node = leo_refine_fairness_node(data,cache,fixed,pool,initialUpper,options,budget)
%LEO_REFINE_FAIRNESS_NODE V12：max s的完整组列生成，s未封顶在1。
% LP含各块凸组合、A_i/q_i-s>=margin_i/q_i和有效无干扰s上界。
K=data.shape(1); M=data.shape(2); limit=leo_fairness_limit(data);
[~,margin]=leo_service_adjustment(data); marginRatio=margin./data.qosTargetBits;
scale=1e6./data.qosTargetBits;
node=struct('upper',initialUpper,'hardInfeasible',false,'status','time_limit','fractionalX',[], ...
    'pool',pool,'roundedCandidates',{{}},'trace',struct([]),'rounds',0,'masterFairness',NaN);
seed=leo_price_node(data,cache,zeros(K,1),fixed,budget,false,zeros(K,1));
if ~seed.complete, return; end
if seed.hardInfeasible, node.upper=-Inf; node.hardInfeasible=true; node.status='hard_infeasible'; return; end
for m=1:M
    x=pool.groups{m}; a=pool.service{m};
    keep=all(bsxfun(@or,fixed(:,m)==-1,bsxfun(@eq,x,fixed(:,m))),1);
    x=x(:,keep); a=a(:,keep);
    if isempty(x), x=seed.groups(:,m); a=seed.service(:,m); end
    pool.groups{m}=x; pool.service{m}=a;
end
x0=false(K,M); ratio=zeros(K,M);
for m=1:M, x0(:,m)=pool.groups{m}(:,1); ratio(:,m)=scale.*pool.service{m}(:,1); end
% z=[每块首组; s; QoS surplus; artificial deficit; s上界slack]。
master.A=[eye(M),zeros(M,2*K+2);ratio,-ones(K,1),-eye(K),eye(K),zeros(K,1); ...
    zeros(1,M),1,zeros(1,2*K),1];
master.b=[ones(M,1);marginRatio;limit];
master.c=[zeros(M,1);1;zeros(K,1);-options.artificialPenalty*ones(K,1);0];
surplus=M+1+(1:K); artificial=M+1+K+(1:K);
master.basis=[1:M,surplus,M+2*K+2];
missing=find(sum(ratio,2)<marginRatio); master.basis(M+missing)=artificial(missing);
master.owner=[1:M,zeros(1,2*K+2)]; master.groups=[x0,false(K,2*K+2)];
for m=1:M
    for j=2:size(pool.groups{m},2), master=append(master,m,pool.groups{m}(:,j),scale.*pool.service{m}(:,j),M); end
end
for iteration=1:options.maxIterations
    if toc(budget.timer)>=budget.seconds, break; end
    lp=leo_simplex_feasible(master.A,master.b,master.c,master.basis,budget,options.maxSimplexPivots);
    master.basis=lp.basis;
    if any(~isfinite(lp.dual)), node.status='numerical_master_failure'; break; end
    lambda=max(0,-lp.dual(M+(1:K)));
    if lp.feasible
        node.fractionalX=zeros(K,M); node.roundedCandidates=cell(1,options.roundingCandidates);
        for j=1:options.roundingCandidates, node.roundedCandidates{j}=false(K,M); end
        for m=1:M
            ids=find(master.owner==m); weights=lp.x(ids);
            node.fractionalX(:,m)=master.groups(:,ids)*weights;
            cumulative=cumsum(weights)/sum(weights);
            for j=1:options.roundingCandidates
                if j==1, [~,choice]=max(weights);
                else, choice=find(cumulative>=mod(j*.61803398875+m*.41421356237,1),1,'first'); end
                if isempty(choice), choice=numel(ids); end
                node.roundedCandidates{j}(:,m)=master.groups(:,ids(choice));
            end
        end
        node.masterFairness=lp.x(M+1);
    end
    priced=leo_price_node(data,cache,lambda.*scale,fixed,budget,false,zeros(K,1));
    if ~priced.complete, break; end
    if priced.hardInfeasible, node.upper=-Inf; node.hardInfeasible=true; node.status='hard_infeasible'; break; end
    auxiliary=limit*max(0,1-sum(lambda)); deduction=lambda.'*marginRatio;
    upper=max(0,auxiliary+priced.total-deduction); % 包括G截断导致的零公平可行日程。
    upper=upper+1e-9*max(1,abs(auxiliary)+abs(priced.total)+abs(deduction));
    node.upper=min(node.upper,upper); node.rounds=iteration;
    row=struct('iteration',iteration,'candidateFairnessUpper',upper,'bestFairnessUpper',node.upper, ...
        'masterFairness',node.masterFairness,'lambdaSum',sum(lambda),'columns',sum(master.owner>0));
    node.trace=leo_append_struct(node.trace,row);
    violation=max(priced.support(:)-lp.dual(1:M));
    if lp.feasible && violation<=options.pricingTolerance, node.status='full_lp_priced'; break; end
    added=0;
    for m=1:M
        group=priced.groups(:,m);
        if any(all(bsxfun(@eq,pool.groups{m},group),1)), continue; end
        pool.groups{m}(:,end+1)=group; pool.service{m}(:,end+1)=priced.service(:,m);
        master=append(master,m,group,scale.*priced.service(:,m),M); added=added+1;
    end
    if added==0, node.status=['master_stalled_',lp.status]; break; end
end
node.pool=pool;
end
function master=append(master,m,group,ratio,M)
e=zeros(M,1); e(m)=1;
master.A(:,end+1)=[e;ratio;0]; master.c(end+1,1)=0;
master.owner(end+1)=m; master.groups(:,end+1)=group;
end
