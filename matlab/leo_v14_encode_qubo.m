function q=leo_v14_encode_qubo(q,factor)
% 有界二进制松弛权重总和恰好L，排除旧编码的多余容量取值。
n=q.nUsers; d=q.slackWeights;
if q.capacityIncluded
    b=numel(d); d=[2.^(0:b-2),q.maxStreams-(2^(b-1)-1)].';
end
N=n+numel(d); Q=zeros(N); Q(1:n,1:n)=-diag(q.A)+q.B/2;
same=bsxfun(@eq,q.beamIndex,q.beamIndex.'); same(1:n+1:end)=false;
penalty=factor*max([q.A;0]); if penalty<=0, penalty=1; end
Q(1:n,1:n)=Q(1:n,1:n)+penalty*double(same)/2; constant=0;
if q.capacityIncluded
    v=[ones(n,1);d]; Q=Q+penalty*(v*v.'-2*q.maxStreams*diag(v)); constant=penalty*q.maxStreams^2;
end
q.slackWeights=d; q.Qsym=Q; q.Qupper=diag(diag(Q))+2*triu(Q,1); q.constant=constant;
q.capacityPenalty=penalty*q.capacityIncluded; q.beamPenalty=penalty; q.nBits=N;
end
