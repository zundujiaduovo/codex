function pool=leo_v14_select_candidates(data,m,q,groups,sources,context,limit)
% 在代理删减前为瓶颈获益、补偿其他用户、原式公平各保留名额。
[~,at]=unique(groups.','rows','stable'); groups=logical(groups(:,at)); sources=sources(at);
bits=leo_resource_group_services(data,m,groups); delta=bsxfun(@minus,bits,context.service.resourceBits(:,m));
gain=bsxfun(@rdivide,delta,data.qosTargetBits);
[~,weak]=sort(context.service.demandRatio); weak=weak(1:min(3,numel(weak)));
ratios=bsxfun(@plus,context.service.demandRatio,gain);
z=double(groups(q.userIds,:)); proxy=q.A.'*z-sum(z.*(q.B*z),1)/2;
selected=1; labels=sources;
take(proxy,1,'proxy');
for i=weak(:).', take(gain(i,:),1,'bottleneck'); end
other=setdiff(1:data.shape(1),weak);
take(sum(max(0,gain(other,:)),1),2,'compensation');
take(min(ratios,[],1),2,'fairness');
take(sum(delta,1),1,'throughput');
take(proxy,limit,'proxy_fill');
pool=struct('groups',groups(:,selected),'sources',{labels(selected)},'resourceBits',bits(:,selected), ...
    'preselectionEvaluations',size(groups,2));
    function take(values,count,label)
        [~,order]=sort(values,'descend'); added=0;
        for j=order
            if numel(selected)>=limit || added>=count, break; end
            if any(selected==j), continue; end
            selected(end+1)=j; labels{j}=label; added=added+1; %#ok<AGROW>
        end
    end
end
