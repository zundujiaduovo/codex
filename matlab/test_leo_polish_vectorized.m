function test_leo_polish_vectorized()
%TEST_LEO_POLISH_VECTORIZED 新向量实现与旧扫描逐动作一致，包含空组与平局。
previous=rng; cleanup=onCleanup(@() rng(previous)); %#ok<NASGU>
rng(193,'twister');
for n=[1,4,12,32]
    for trial=1:25
        q.nUsers=n; q.maxStreams=min(8,n); q.A=randn(n,1);
        matrix=rand(n); q.B=matrix+matrix.'; q.B(1:n+1:end)=0;
        q.beamIndex=mod((1:n).',max(1,ceil(n/2)))+1;
        x=leo_repair_group(q,rand(n,1)<.5);
        a=leo_polish_group(q,x,6); b=reference(q,x,6);
        assert(isequal(a,b));
        q.A(:)=0; q.B(:)=0;
        assert(isequal(leo_polish_group(q,x,6),reference(q,x,6)));
    end
end
q.A=zeros(0,1); q.B=zeros(0); q.beamIndex=zeros(0,1); q.maxStreams=1;
assert(isempty(leo_polish_group(q,false(0,1),6)));
for trial=1:10
    q.nUsers=64; q.maxStreams=16; q.A=randn(64,1); a=rand(64); q.B=a+a.'; q.B(1:65:end)=0;
    q.beamIndex=mod((1:64).',32)+1; x=leo_repair_group(q,rand(64,1)<.5);
    for moves=[6,12], assert(isequal(leo_polish_group(q,x,moves),reference(q,x,moves))); end
end
fprintf('PASS: vectorized polish matches legacy actions/ties, empty/flat groups and 64-user 16-stream groups with 6/12 moves.\n');
end
function x=reference(q,x,moves)
for step=1:moves
    marginal=q.A-q.B*double(x); gain=0; add=0; drop=0;
    chosen=find(x); absent=find(~x);
    for j=chosen.'
        if -marginal(j)>gain, gain=-marginal(j); drop=j; add=0; end
    end
    for i=absent.'
        conflicts=chosen(q.beamIndex(chosen)==q.beamIndex(i));
        if isempty(conflicts) && numel(chosen)<q.maxStreams && marginal(i)>gain
            gain=marginal(i); add=i; drop=0;
        end
        for j=chosen.'
            if ~isempty(conflicts) && any(conflicts~=j), continue; end
            change=marginal(i)-marginal(j)+q.B(i,j);
            if change>gain, gain=change; add=i; drop=j; end
        end
    end
    if gain<=1e-13*max(1,sum(abs(q.A))), break; end
    if drop>0, x(drop)=false; end
    if add>0, x(add)=true; end
end
end
