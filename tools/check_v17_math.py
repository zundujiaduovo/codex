"""Independent exhaustive checks of V17's proxy bound and tangent construction.

This checks the mathematical inequalities, not execution of the MATLAB source.
MATLAB implementation regressions are provided in TEST_V17.
"""
from itertools import product
import numpy as np


def check_proxy_nodes():
    rng=np.random.default_rng(170017)
    checked=0
    n=8
    bits=np.array(list(product((0,1),repeat=n)),dtype=float)
    for case in range(80):
        a=rng.normal(size=n)
        b=rng.normal(size=(n,n)); b=(b+b.T)/2; np.fill_diagonal(b,0)
        beams=np.array([0,0,1,2,2,3,4,5]); capacity=3
        feasible=bits.sum(1)<=capacity
        for beam in np.unique(beams):
            feasible &= bits[:,beams==beam].sum(1)<=1
        legal=bits[feasible]
        values=legal@a-np.einsum('ij,jk,ik->i',legal,b,legal)/2
        for _ in range(50):
            chosen=legal[rng.integers(len(legal))].astype(bool)
            free=(rng.random(n)>.4) & ~chosen
            for beam in beams[chosen]: free[beams==beam]=False
            node_value=a@chosen-chosen@b@chosen/2
            ids=np.flatnonzero(free)
            gains=a[ids]-b[ids]@chosen
            gains+=np.maximum(0,-b[np.ix_(ids,ids)]).sum(1)/2
            beam_gains=sorted((max(0,float(gains[beams[ids]==beam].max()))
                               for beam in np.unique(beams[ids])),reverse=True)
            upper=node_value+sum(beam_gains[:capacity-int(chosen.sum())])
            descendants=np.all(legal[:,chosen]==1,axis=1) & np.all(legal[:,~(chosen|free)]==0,axis=1)
            optimum=values[descendants].max()
            assert upper>=optimum-1e-10,(case,upper,optimum)
            checked+=1
    return checked


def check_tangents():
    rng=np.random.default_rng(170018); checked=0
    for _ in range(100):
        signal,noise=np.exp(rng.normal(size=2))
        limits=np.linspace(0,20,101)
        actual=np.log2(1+signal/(noise+limits))
        # A counterfactual or interpolated interference is a legal tangent point.
        for ref in np.clip(rng.normal(10,12,size=8),0,20):
            slope=-signal/(np.log(2)*(noise+ref)*(noise+ref+signal))
            line=np.log2(1+signal/(noise+ref))+slope*(limits-ref)
            assert np.all(line<=actual+1e-12)
            checked+=len(limits)
    return checked


def check_batched_dynamics():
    """Matrix trajectory updates agree with independent scalar-trajectory updates."""
    rng=np.random.default_rng(170019); checked=0
    for dtype in (np.float32,np.float64):
        for _ in range(12):
            n,r=11,64
            j=rng.normal(size=(n,n)); j=(j+j.T)/2; np.fill_diagonal(j,0)
            h=rng.normal(size=n)
            scale=np.max(np.abs(j).sum(1)+np.abs(h)); j=(j/scale).astype(dtype); h=(h/scale).astype(dtype)
            p=(.05*rng.normal(size=(n,r))).astype(dtype); v=(.05*rng.normal(size=(n,r))).astype(dtype)
            slow_p=p.copy(); slow_v=v.copy(); ages=rng.integers(0,20,size=r)
            ids=np.flatnonzero(rng.random(r)>.2)
            for step in range(60):
                ages[ids]+=1; pump=np.minimum(1,ages[ids]/80).astype(dtype)
                pp=p[:,ids]; vv=v[:,ids]
                force=pp*(pump-1)-(j@pp+h[:,None]); vv=vv+dtype(.15)*force; pp=pp+dtype(.15)*vv
                vv[np.abs(pp)>1]=0; pp=np.clip(pp,-1,1); p[:,ids]=pp; v[:,ids]=vv
                for i in ids:
                    factor=dtype(min(1,ages[i]/80)-1)
                    force=factor*slow_p[:,i]-(j@slow_p[:,i]+h)
                    slow_v[:,i]+=dtype(.15)*force; slow_p[:,i]+=dtype(.15)*slow_v[:,i]
                    slow_v[np.abs(slow_p[:,i])>1,i]=0; slow_p[:,i]=np.clip(slow_p[:,i],-1,1)
                assert np.allclose(p,slow_p,atol=2e-4,rtol=2e-4)
                assert np.allclose(v,slow_v,atol=2e-4,rtol=2e-4)
                checked+=len(ids)
    return checked


if __name__=='__main__':
    nodes=check_proxy_nodes(); tangents=check_tangents(); trajectories=check_batched_dynamics()
    print(f'PASS: {nodes} proxy branch bounds against exhaustive feasible descendants; {tangents} tangent lower-bound comparisons.')
    print(f'PASS: {trajectories} batched/scalar trajectory updates in single and double precision.')
    print('Independent mathematics only; MATLAB execution and parallel timing are separate.')
