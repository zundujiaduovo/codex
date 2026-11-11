function result = leo_cardinality_fairness_bound(report,overrides,cache)
%LEO_CARDINALITY_FAIRNESS_BOUND 配置LP松弛的对偶界：人数、同波束互斥和人数条件干扰。
% 每块每个合法组g的服务放松为u(i,m,|g|)*1{i in g}。
% LP允许组的凸组合；定价通过每波束取最大、再取n个最大值精确完成。
% 任意非负lambda都产生有效上界；不把受限主问题的原始值当上界。
if nargin<2, overrides=struct(); end
o=struct('maxSeconds',30,'maxIterations',150,'maxPivots',10000,'tolerance',1e-7);
names=fieldnames(overrides); assert(all(ismember(names,fieldnames(o))));
for j=1:numel(names), o.(names{j})=overrides.(names{j}); end
assert(o.maxSeconds>=0 && isfinite(o.maxSeconds) && o.maxIterations>=1 && o.maxPivots>=1 && o.tolerance>0);
data=report.problemData; K=data.shape(1); M=data.shape(2); started=tic;
budget=struct('timer',started,'seconds',o.maxSeconds);
if nargin<3, cache=leo_prepare_upper_bounds(data); end
limit=leo_fairness_limit(data); [~,margin]=leo_service_adjustment(data); marginRatio=margin./data.qosTargetBits;
% 向外留浮点余量；原始u系数只来自原模型条件干扰上界。
u=bsxfun(@rdivide,cache.serviceByCardinality.*(1+1e-10)+1e-6,reshape(data.qosTargetBits,K,1,1));
groups=cell(1,M); rates=cell(1,M);
for m=1:M, groups{m}=false(K,1); rates{m}=zeros(K,1); end
schedules={};
for j=1:numel(report.records)
    if ~strcmp(report.records(j).status,'completed') || isempty(report.solutions{j}), continue; end
    s=report.solutions{j}; schedules{end+1}=s.x; %#ok<AGROW>
    if isfield(s,'stage1'), schedules{end+1}=s.stage1.x; end %#ok<AGROW>
end
if isfield(report,'fairnessCertificate'), schedules{end+1}=report.fairnessCertificate.incumbentX; end
knownLower=0;
for j=1:numel(schedules)
    exact=leo_evaluate_service(data,schedules{j}); knownLower=max(knownLower,exact.fairness);
    for m=1:M
        g=logical(schedules{j}(:,m)); n=nnz(g);
        if any(all(bsxfun(@eq,groups{m},g),1)), continue; end
        groups{m}(:,end+1)=g; rates{m}(:,end+1)=u(:,m,n).*g;
    end
end
[uniform,~]=price(ones(K,1)/K); upper=min(limit,uniform);
result=struct('schemaVersion',1,'kind','Cardinality configuration LP: verified dual upper bound', ...
    'upper',upper,'coarseUpper',limit,'uniformUpper',upper,'lpValue',NaN,'lpConverged',false, ...
    'lambda',ones(K,1)/K,'iterations',0,'trace',struct([]),'status','time_limit', ...
    'scope','Global ORIGINAL max-min upper bound. LP convexifies legal per-block groups and uses cardinality-conditioned ORIGINAL rate upper bounds; all beams/users remain eligible.');
% 主问题维数为M+K+1行，不枚举2^B组；人工变量仅用于主问题可行基。
master.A=[eye(M),zeros(M,2*K+2);zeros(K,M),-ones(K,1),-eye(K),eye(K),zeros(K,1); ...
    zeros(1,M),1,zeros(1,2*K),1];
master.b=[ones(M,1);marginRatio;limit];
master.c=[zeros(M,1);1;zeros(K,1);-1000*ones(K,1);0];
master.basis=[1:M,M+1+(1:K),M+2*K+2];
missing=find(marginRatio>0); master.basis(M+missing)=M+1+K+missing;
for m=1:M, for j=2:size(groups{m},2), append(m,rates{m}(:,j)); end; end
for iteration=1:o.maxIterations
    if leo_budget_expired(budget), break; end
    lp=leo_simplex_feasible(master.A,master.b,master.c,master.basis,budget,o.maxPivots);
    master.basis=lp.basis;
    if any(~isfinite(lp.dual)), result.status='numerical_master_failure'; break; end
    lambda=max(0,-lp.dual(M+(1:K)));
    [candidate,priced]=price(lambda);
    if candidate<upper, upper=candidate; result.lambda=lambda; end
    result.iterations=iteration; result.lpValue=lp.x(M+1);
    row=struct('iteration',iteration,'dualUpper',candidate,'bestUpper',upper, ...
        'restrictedLPValue',result.lpValue,'lambdaSum',sum(lambda),'columns',size(master.A,2));
    result.trace=leo_append_struct(result.trace,row);
    artificial=sum(lp.x(M+1+K+(1:K)));
    violation=max(priced.support-lp.dual(1:M));
    if lp.feasible && strcmp(lp.status,'optimal') && artificial<=o.tolerance && ...
            violation<=o.tolerance && upper-result.lpValue<=10*o.tolerance*max(1,abs(upper))
        result.lpConverged=true; result.status='LP_optimal_dual_verified'; break;
    end
    added=0;
    for m=1:M
        g=priced.groups(:,m);
        if any(all(bsxfun(@eq,groups{m},g),1)), continue; end
        groups{m}(:,end+1)=g; rates{m}(:,end+1)=priced.rates(:,m);
        append(m,priced.rates(:,m)); added=added+1;
    end
    if added==0, result.status=['master_stalled_',lp.status]; break; end
    result.status='iteration_limit';
end
assert(upper>=knownLower-1e-8*max(1,abs(upper)),'Configuration LP bound is below a verified original feasible value.');
if ~result.lpConverged && leo_budget_expired(budget), result.status='time_limit_valid_dual_bound'; end
result.upper=upper; result.elapsedSeconds=toc(started); result.options=o;
    function append(m,a)
        e=zeros(M,1); e(m)=1; master.A(:,end+1)=[e;a;0]; master.c(end+1,1)=0;
    end
    function [value,out]=price(lambda)
        out.groups=false(K,M); out.rates=zeros(K,M); out.support=zeros(M,1);
        for mm=1:M
            ids=find(data.available(:,mm)); beams=unique(data.beamIndex(ids,mm)); B=numel(beams);
            nMax=min(data.maxStreams,B); winners=zeros(B,nMax); values=zeros(B,nMax);
            for bb=1:B
                ii=ids(data.beamIndex(ids,mm)==beams(bb));
                a=reshape(u(ii,mm,1:nMax),numel(ii),nMax);
                [values(bb,:),at]=max(bsxfun(@times,a,lambda(ii)),[],1); winners(bb,:)=ii(at);
            end
            for nn=1:nMax
                [v,order]=sort(values(:,nn),'descend'); score=sum(v(1:nn));
                if score<=out.support(mm), continue; end
                chosen=winners(order(1:nn),nn); out.groups(:,mm)=false;
                out.groups(chosen,mm)=true; out.rates(:,mm)=u(:,mm,nn).*out.groups(:,mm);
                out.support(mm)=score;
            end
        end
        auxiliary=limit*max(0,1-sum(lambda)); deduction=lambda.'*marginRatio;
        value=max(0,auxiliary+sum(out.support)-deduction);
        value=value+1e-9*max(1,abs(auxiliary)+sum(abs(out.support))+abs(deduction));
    end
end
