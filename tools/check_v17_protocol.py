"""Small independent checks of convergence-window and batch-partition logic.
Does not execute MATLAB or claim parallel speedup/64-user convergence quality.
"""
from pathlib import Path


def convergence(values, minimum, window=100, stable_required=3):
    anchor, start, stable = values[0], 0, 0
    for k, value in enumerate(values[1:], 1):
        if k-start >= window:
            gain, tolerance = value-anchor, max(1e-8, 1e-6*abs(anchor))
            stable = stable+1 if gain<=tolerance else 0
            anchor, start = value, k
        if k>=minimum and stable>=stable_required:
            return k
    return None


def main():
    assert convergence([2.0]*1500, 240)==300
    assert convergence([2.0]*2500, 2000)==2000
    assert convergence([2+k*1e-6 for k in range(3000)], 240) is None
    values=[2.0]*201+[2.1]*700
    assert convergence(values, 240)==600  # meaningful window gain resets count
    for r in (1, 8, 31, 32, 64, 65, 128):
        batches=[list(range(first, min(first+8, r))) for first in range(0, r, 8)]
        assert sum(batches, [])==list(range(r))
    root=Path(__file__).resolve().parents[1]
    settings=(root/'V17_SETTINGS.m').read_text()
    assert "'sbTrajectories',64" in settings and "'enabled',true" in settings
    assert "'workers',4,'batchSize',8" in settings
    assert "'backend','gpu'" in settings and "'precision','single'" in settings
    assert 'while unlimited || k<rounds' in (root/'matlab/leo_v14_run_price_phase.m').read_text()
    assert 'while unlimited || iteration<phaseCap' in (root/'matlab/leo_solve_original_search.m').read_text()
    assert 'parfor b=1:count' in (root/'matlab/leo_v16_parallel_sb.m').read_text()
    prepare=(root/'matlab/leo_v16_prepare_parallel.m').read_text()
    assert 'pool.NumWorkers~=workers' in prepare and 'delete(pool)' in prepare
    phase=(root/'matlab/leo_v14_run_price_phase.m').read_text()
    assert 'if memory.retainStateHistory' in phase and 'numel(evidence)>=memory.maxEvidenceRows' in phase
    benchmark=(root/'matlab/leo_benchmark_case.m').read_text()
    assert 'not_run_memory_pressure' in benchmark and 'leo_v17_is_memory_error(err)' in benchmark
    print('PASS: cumulative plateaus, continued improvement, original minimum, complete 64-trajectory partition and production loop/parallel wiring.')
    print('Not MATLAB execution, worker speed measurement or 64-user optimization validation.')
    gpu=(root/'matlab/leo_v17_gpu_sb.m').read_text()
    assert 'gpuArray(cast(a,e.precision))' in gpu and 'J*pp' in gpu and 'toHost(p(:,ids)>=0)' in gpu
    resource=(root/'matlab/leo_v14_solve_resource.m').read_text()
    assert resource.index('leo_v17_gpu_sb')<resource.index('leo_v16_parallel_sb')
    print('PASS: GPU matrix dynamics, CPU fallback pool resizing, bounded diagnostics and OOM failure handling are wired.')


if __name__=='__main__':
    main()
