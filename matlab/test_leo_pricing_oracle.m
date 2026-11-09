function test_leo_pricing_oracle()
%TEST_LEO_PRICING_ORACLE 原始组枚举独立检查带截断/整数计数割/分支限制的精确定价。
p=leo_default_parameters(); p.statistics.serviceModel='slot_union'; p.system.K=4;
p.system.maxStreams=2; p.system.bandwidthHz=1e6; p.system.qosTargetBits=[.3;.4;.5;.6]*1e6;
p.time.nSlots=4; p.time.blockSlots=2; p.time.slotDurationS=.5;
p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
r=leo_build_resources(p); b.available=true(4,2); b.index=repmat([1;1;2;3],1,2);
d.signalW=[1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
d.noiseW=repmat([1,2,1.5,3],4,1); d.beamPowerW=zeros(4,3,4); d.serviceModel='slot_union';
for t=1:4, d.beamPowerW(:,:,t)=[2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem=leo_form_problem(p,r,b,d); data=problem.data;
options=struct('maxBeams',18,'maxSubsets',100000,'maxTotalSubsets',100000,'verbose',false);
budget=struct('timer',tic,'seconds',20); cache=leo_prepare_pricing_cache(data,options,budget);
[~,margin]=leo_service_adjustment(data); target=(data.qosTargetBits+margin)/1e6;
for mode=0:1
 for trial=1:5
  fixed=-ones(4,2,'int8');
  if trial==2, fixed(1,1)=1; fixed(2,2)=0; end
  if trial==3, fixed(1:2,1)=1; end % 同波束两个必选用户，硬不可行。
  if trial==4, fixed(1:3,2)=0; end
  if trial==5, fixed(1,1)=0; fixed(3,1)=1; fixed(4,2)=1; end
  lambda=[.1;.7;2;.3]; if mode, lambda=[lambda; .2;.4;.1;.8]; end
  exact=0; impossible=false;
  for m=1:2
   best=-Inf;
   for code=0:15
    group=logical(bitget(code,1:4)).';
    if sum(group)>2 || numel(unique(data.beamIndex(group,m)))~=sum(group), continue; end
    if any(fixed(:,m)~=-1 & group~=fixed(:,m)), continue; end
    a=leo_resource_service(data,m,group)/1e6;
    if mode, cover=min(a,target); bonus=lambda(5:end).'*double(group); else, cover=a; bonus=0; end
    best=max(best,sum(a)+lambda(1:4).'*cover+bonus);
   end
   if ~isfinite(best), impossible=true; break; end
   exact=exact+best;
  end
  got=leo_price_node(data,cache,lambda,fixed,budget,logical(mode));
  assert(got.complete && got.hardInfeasible==impossible);
  if ~impossible, assert(abs(got.total-exact)<1e-9*max(1,abs(exact))); end
 end
end
best=-Inf; bestX=[];
for code=0:255
 x=reshape(logical(bitget(code,1:8)),4,2);
 if any(data.hard.A*double(x(:))>data.hard.rhs), continue; end
 s=problem.evaluate(x);
 if all(s.userBits>=data.qosTargetBits)
  assert(all(sum(x,2)>=cache.minimumCounts));
  assert(all(sum(min(s.resourceBits/1e6,repmat(target,1,2)),2)>=target-1e-12));
  if s.totalBits>best, best=s.totalBits; bestX=x; end
 end
end
assert(isfinite(best));
report=struct('problemData',data,'parameters',p, ...
 'records',struct('method','empty','seed',1,'status','completed'),'solutions',{{struct('x',false(4,2))}});
t=leo_theory_bound(report,struct('maxSeconds',15,'maxNodes',32,'verbose',false));
assert(t.upperBits>=best-1e-5 && (isnan(t.lowerBits) || t.lowerBits<=best+1e-5));
if ~isempty(t.incumbentX), s=problem.evaluate(t.incumbentX); assert(all(s.userBits>=data.qosTargetBits)); end
fprintf('PASS: independently enumerated capped/count pricing under branch fixes, valid count cuts and unknown-incumbent certificate search.\n');
end
