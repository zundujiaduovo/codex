function node = leo_refine_certificate_node(data,cache,fixed,pool,initialUpper,options,budget)
%LEO_REFINE_CERTIFICATE_NODE 用可行基单纯形+完整组定价求节点LP上界。
% 人工缺口变量只用于主问题初始化；上界总是重新按完整原组集合定价。
K=data.shape(1); M=data.shape(2); [~,margin]=leo_service_adjustment(data);
target=(data.qosTargetBits+margin)/1e6; marginTotal=sum(margin)/1e6;
if options.countCuts, target=[target;cache.minimumCounts]; end
R=numel(target);
node=struct('upper',initialUpper,'hardInfeasible',false,'status','time_limit', ...
 'fractionalX',[],'roundedX',[],'pool',pool,'trace',struct([]),'lambda',zeros(R,1), ...
 'roundedCandidates',{{}},'rounds',0,'simplexPivots',0,'artificialSum',NaN,'artificialServiceBits',NaN,'artificialCountDeficit',NaN,'masterValue',NaN);
seed=leo_price_node(data,cache,zeros(R,1),fixed,budget,options.cappedService);
if ~seed.complete, return; end
if seed.hardInfeasible, node.hardInfeasible=true; node.upper=-Inf; node.status='hard_infeasible'; return; end
% 分支只过滤不合法列；未生成组仍由完整定价覆盖，不能当成全域已穷举。
for m=1:M
    X=pool.groups{m}; A=pool.service{m};
    keep=all(bsxfun(@or,fixed(:,m)==-1,bsxfun(@eq,X,fixed(:,m))),1);
    X=X(:,keep); A=A(:,keep);
    if isempty(X), X=seed.groups(:,m); A=seed.service(:,m); end
    pool.groups{m}=X; pool.service{m}=A;
end
initialX=false(K,M); initialA=zeros(K,M);
for m=1:M, initialX(:,m)=pool.groups{m}(:,1); initialA(:,m)=pool.service{m}(:,1); end
coverage=initialA;
if options.cappedService, coverage=bsxfun(@min,initialA,target(1:K)); end
if options.countCuts, coverage=[coverage;double(initialX)]; end
master.A=[eye(M),zeros(M,2*R);coverage,-eye(R),eye(R)];
master.b=[ones(M,1);target];
master.c=[sum(initialA,1).';zeros(R,1);-options.artificialPenalty*ones(R,1)];
master.basis=[1:M,M+(1:R)];
difference=sum(coverage,2)-target;
master.basis(M+find(difference<0))=M+R+find(difference<0);
master.owner=[1:M,zeros(1,2*R)]; master.groups=[initialX,false(K,2*R)];
for m=1:M
 for j=2:size(pool.groups{m},2)
    master=append(master,m,pool.groups{m}(:,j),pool.service{m}(:,j),M,target,options.cappedService,options.countCuts);
 end
end
for iteration=1:options.maxIterations
    if toc(budget.timer)>=budget.seconds, break; end
    lp=leo_simplex_feasible(master.A,master.b,master.c,master.basis,budget,options.maxSimplexPivots);
    master.basis=lp.basis; node.simplexPivots=node.simplexPivots+lp.pivots;
    if any(~isfinite(lp.dual)), node.status='numerical_master_failure'; break; end
    lambda=max(0,-lp.dual(M+1:end));
    if lp.feasible
        node.fractionalX=zeros(K,M); node.roundedX=false(K,M);
        node.roundedCandidates=cell(1,options.roundingCandidates);
        for j=1:options.roundingCandidates, node.roundedCandidates{j}=false(K,M); end
        for m=1:M
            ids=find(master.owner==m); weights=lp.x(ids);
            node.fractionalX(:,m)=master.groups(:,ids)*weights;
            [~,j]=max(weights); node.roundedX(:,m)=master.groups(:,ids(j));
            cumulative=cumsum(weights)/sum(weights);
            for j=1:options.roundingCandidates
                quantile=mod(j*.61803398875+m*.41421356237,1);
                choice=find(cumulative>=quantile,1,'first');
                if isempty(choice), choice=numel(ids); end
                node.roundedCandidates{j}(:,m)=master.groups(:,ids(choice));
            end
        end
        node.artificialSum=sum(lp.x(M+R+(1:R)));
        node.artificialServiceBits=sum(lp.x(M+R+(1:K)))*1e6;
        node.artificialCountDeficit=sum(lp.x(M+R+(K+1:R)));
        node.masterValue=lp.objective-marginTotal;
    end
    priced=leo_price_node(data,cache,lambda,fixed,budget,options.cappedService);
    if ~priced.complete, break; end
    if priced.hardInfeasible, node.hardInfeasible=true; node.upper=-Inf; node.status='hard_infeasible'; break; end
    deduction=lambda.'*target+marginTotal;
    upper=priced.total-deduction;
    upper=upper+1e-9*max(1,abs(priced.total)+abs(deduction));
    if upper<node.upper, node.upper=upper; node.lambda=lambda; end
    node.rounds=iteration;
    row=struct('iteration',iteration,'candidateUpperBits',upper*1e6, ...
        'bestUpperBits',node.upper*1e6,'masterValueBits',node.masterValue*1e6, ...
        'artificialDeficitBits',node.artificialServiceBits,'artificialCountDeficit',node.artificialCountDeficit,'columns',sum(master.owner>0), ...
        'lambdaL2',norm(lambda),'simplexPivots',lp.pivots);
    if isempty(node.trace), node.trace=row; else, node.trace(end+1,1)=row; end
    violation=max(priced.support(:)-lp.dual(1:M));
    if violation<=options.pricingTolerance && lp.feasible
        node.status='full_lp_priced'; break;
    end
    added=0;
    for m=1:M
        group=priced.groups(:,m);
        if any(all(bsxfun(@eq,pool.groups{m},group),1)), continue; end
        pool.groups{m}(:,end+1)=group; pool.service{m}(:,end+1)=priced.service(:,m);
        master=append(master,m,group,priced.service(:,m),M,target,options.cappedService,options.countCuts); added=added+1;
    end
    if added==0, node.status=['master_stalled_',lp.status]; break; end
    if iteration==options.maxIterations, node.status='pricing_iteration_limit'; end
end
node.pool=pool;
end
function master=append(master,m,group,service,M,target,capped,countCuts)
e=zeros(M,1); e(m)=1;
coverage=service; if capped, coverage=min(service,target(1:numel(service))); end
if countCuts, coverage=[coverage;double(group)]; end
master.A(:,end+1)=[e;coverage]; master.c(end+1,1)=sum(service);
master.owner(end+1)=m; master.groups(:,end+1)=group;
end
