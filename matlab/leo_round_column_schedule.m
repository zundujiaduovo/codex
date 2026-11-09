function rounded = leo_round_column_schedule(data,pool,x,budget,maxPasses)
%LEO_ROUND_COLUMN_SCHEDULE 列池上的整数块协调；只产生候选，下界须原评价器复核。
K=data.shape(1); M=data.shape(2); [~,margin]=leo_service_adjustment(data);
target=(data.qosTargetBits+margin)/1e6; bits=zeros(K,M);
for m=1:M, bits(:,m)=leo_resource_service(data,m,x(:,m))/1e6; end
for pass=1:maxPasses
 if toc(budget.timer)>=budget.seconds, break; end
 total=sum(bits,2); feasible=all(total>=target); changed=false;
 order=mod((0:M-1)+pass-1,M)+1;
 for m=order
  if toc(budget.timer)>=budget.seconds, break; end
  candidates=bsxfun(@plus,pool.service{m},total-bits(:,m));
  deficit=sum(max(0,bsxfun(@minus,target,candidates)),1);
  score=sum(candidates,1)-1e6*deficit;
  if feasible, score(any(bsxfun(@lt,candidates,target),1))=-Inf; end
  current=sum(total)-1e6*sum(max(0,target-total));
  [best,j]=max(score);
  if best>current+1e-10
   x(:,m)=pool.groups{m}(:,j); bits(:,m)=pool.service{m}(:,j);
   total=sum(bits,2); feasible=all(total>=target); changed=true;
  end
 end
 if ~changed, break; end
end
rounded.x=x; rounded.service=leo_evaluate_service(data,x);
end
