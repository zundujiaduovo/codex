function test_leo_v15_certificates()
% Exhaustive original binary groups verify interrupted/full pricing and resume.
previous=rng; cleanup=onCleanup(@()rng(previous)); rng(712,'twister'); %#ok<NASGU>
[problem,report]=leo_test_problem(); d=problem.data; K=d.shape(1); M=d.shape(2);
o=leo_v15_bound_options(struct('pricingNodesPerCall',1,'verbose',false));
for trial=1:15
    w=rand(K,1); fixed=-ones(K,1,'int8');
    if trial==2, fixed(1)=1; fixed(2)=0; end
    if trial==3, fixed(1:2)=1; end % Same beam, hard infeasible.
    if trial==4, fixed([2,4])=0; end
    if trial==5, w(:)=0; end
    for m=1:M
        optimum=-Inf;
        for code=0:2^K-1
            g=logical(bitget(code,1:K)).';
            if nnz(g)>d.maxStreams || numel(unique(d.beamIndex(g,m)))~=nnz(g) || any(g & ~d.available(:,m)), continue; end
            if any(fixed~=-1 & g~=fixed), continue; end
            optimum=max(optimum,w.'*leo_resource_service(d,m,g)/1e6);
        end
        state=[]; old=Inf;
        for pass=1:200
            [r,state]=leo_v15_price_block(d,m,w,fixed,o,state);
            if ~isfinite(optimum), assert(r.hardInfeasible); break; end
            assert(r.upper>=optimum-1e-10 && r.lower<=optimum+1e-10);
            assert(r.upper<=old+1e-10); old=r.upper;
            assert(abs(r.lower-w.'*leo_resource_service(d,m,r.group)/1e6)<1e-10);
            if r.complete, assert(abs(r.lower-optimum)<1e-10); break; end
        end
        assert(r.complete,'Pricing failed to finish an exhaustively small domain.');
    end
end
best=-Inf; allX={}; services={};
for code=0:2^(K*M)-1
    x=reshape(logical(bitget(code,1:K*M)),K,M);
    if any(x(:)>d.hard.upper) || any(d.hard.A*double(x(:))>d.hard.rhs), continue; end
    s=problem.evaluate(x); allX{end+1}=x; services{end+1}=s; %#ok<AGROW>
    best=max(best,s.fairness);
end
folder=tempname; mkdir(folder); remove=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
settings=struct('maxSweeps',1,'maxBranchNodes',2,'pricingNodesPerCall',1,'relativeGap',1e-7,'verbose',false);
c=leo_v15_certificate(report,fullfile(folder,'fair'),'fairness',0,settings);
assert(c.upper>=best-1e-7 && c.lower<=best+1e-7);
settings.maxSweeps=2000; settings.maxBranchNodes=2000; settings.pricingNodesPerCall=200;
c2=leo_v15_certificate(report,fullfile(folder,'fair'),'fairness',0,settings);
assert(c2.upper<=c.upper+1e-8 && c2.lower>=c.lower && c2.upper>=best-1e-7 && c2.lower<=best+1e-7);
assert(c2.gapTargetMet,'Small full certificate failed to close.');
assert(best>0); floorValue=.7*best; throughput=-Inf;
for j=1:numel(services)
    if all(services{j}.demandRatio>=floorValue)
        throughput=max(throughput,services{j}.totalBits);
        report.solutions{1}=struct('x',allX{j}); % Include a feasible floor witness.
    end
end
t=leo_v15_certificate(report,fullfile(folder,'through'),'throughput',floorValue,settings);
assert(t.upperBits>=throughput-1 && t.lowerBits<=throughput+1 && t.gapTargetMet);
changed=report; changed.problemData.design.signalW(1,1)=changed.problemData.design.signalW(1,1)+.1;
rejected=false; try, leo_v15_certificate(changed,fullfile(folder,'fair'),'fairness',0,settings); catch, rejected=true; end
assert(rejected,'A checkpoint with a different physical model must be rejected.');
fprintf('PASS: V15 true-service interrupted/full pricing, beam conflicts, zero weights, monotone bounds, checkpoint resume, global fairness and conditional throughput vs exhaustive enumeration.\n');
end
