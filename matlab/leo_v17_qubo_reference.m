function r=leo_v17_qubo_reference(q,witness,maxNodes)
% Certified combinatorial upper for the SAME legal proxy block, not the original model.
% Each unfinished node retains an optimistic marginal bound; interrupted search is valid.
if nargin<3, maxNodes=5000; end
timer=tic; best=leo_repair_group(q,witness); lower=score(best); n=q.nUsers;
assert(norm(q.B-q.B.','fro')<=1e-12*max(1,norm(q.B,'fro')) && all(diag(q.B)==0));
root=struct('x',false(n,1),'free',true(n,1),'value',0,'upper',Inf);
root.upper=bound(root); queue=root; visited=0;
while ~isempty(queue) && visited<maxNodes
    [upper,at]=max([queue.upper]); node=queue(at); queue(at)=[];
    if upper<=lower, continue; end
    visited=visited+1;
    if node.value>lower, best=node.x; lower=node.value; end
    ids=find(node.free); if isempty(ids) || sum(node.x)>=q.maxStreams, continue; end
    marginal=q.A-q.B*double(node.x); [~,j]=max(marginal(ids)); i=ids(j);
    exclude=node; exclude.free(i)=false; exclude.upper=bound(exclude);
    if exclude.upper>lower, queue(end+1)=exclude; end %#ok<AGROW>
    include=node; include.x(i)=true; include.value=score(include.x);
    include.free(q.beamIndex==q.beamIndex(i))=false; include.upper=bound(include);
    if include.value>lower, lower=include.value; best=include.x; end
    if include.upper>lower, queue(end+1)=include; end %#ok<AGROW>
end
upper=max([lower,queue.upper]); closed=isempty(queue);
r=struct('lower',lower,'upper',upper,'x',best,'nodes',visited,'closed',closed, ...
    'seconds',toc(timer),'scope','Full legal frozen proxy block; numerical outward guard; not an original-problem certificate.');
    function value=score(x)
        z=double(x); value=q.A.'*z-z.'*q.B*z/2;
    end
    function value=bound(node)
        ids=find(node.free); remaining=q.maxStreams-sum(node.x);
        if isempty(ids) || remaining<=0, value=node.value; return; end
        gains=q.A(ids)-q.B(ids,:)*double(node.x);
        % Positive optional pair interactions may be counted twice at half weight.
        gains=gains+sum(max(0,-q.B(ids,ids)),2)/2;
        beams=unique(q.beamIndex(ids)); beamGain=zeros(numel(beams),1);
        for b=1:numel(beams), beamGain(b)=max([0;gains(q.beamIndex(ids)==beams(b))]); end
        beamGain=sort(beamGain,'descend');
        value=node.value+sum(beamGain(1:min(remaining,numel(beamGain))));
        value=value+1e-10*max(1,abs(value));
    end
end
