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


if __name__=='__main__':
    nodes=check_proxy_nodes(); tangents=check_tangents()
    print(f'PASS: {nodes} proxy branch bounds against exhaustive feasible descendants; {tangents} tangent lower-bound comparisons.')
    print('Independent mathematics only; MATLAB execution and parallel timing are separate.')
