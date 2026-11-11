# V13 adaptive stopping and plain method names

Runtime: Octave 9.4.0 on Linux, one BLAS thread. GUI opening is mocked; PNG figures are rendered from MATLAB-generated JSON with Matplotlib.

- `adaptive_stopping.log`: deterministic-clock checks verify the 1% valid original-bound target, accumulated small improvements, minimum phase time/iteration gates, plateau stopping and the disabled switch. An independent binary oracle calibrates four-method near-optimal stops, including a genuinely suboptimal initial solution whose nonzero gap is below 1%. A loose-bound instance verifies real Tabu/SB/Local loops can report stagnation with a positive gap, without claiming certified near-optimality. RNG and plain aliases are checked.
- `v13_model.log`: the actual 64-user, 64-beam, 16-stream model completes all four methods, preserves stage-1 floors and passes independent original-model re-evaluation from both stage CSV schedules. New V13 records use Tabu/SB/Local/Greedy. Existing legacy names and missing stop instrumentation can be redrawn, preserving benchmark MAT bytes and leaving unknown stop metrics NaN. Pair resume also preserves saved bytes.
- The real-model smoke run uses 20 s/method, one outer round per phase, 10 SB integration steps, two trajectories/restarts, no Monte Carlo and zero certificate-search budget. This validates integration, not the default 120-second performance protocol. Its loose upper bounds and iteration/time stops do not demonstrate near-optimality or method superiority.
- `regression.log`: generic method tests, benchmarks, V12 objective/bounds, diagnostic/exact-block controls, installation checks and both figure viewers pass.
- `plot_specs.json`, `stopping_summary.csv`, `figures/`: real-model smoke exports with plain names; all three figures rendered successfully. No values are fabricated or extrapolated.
- Frozen V8 check: all nine historical files remain unchanged.

The complete V13 source package contains none of these validation results. User settings are in V13_SETTINGS.m; new adaptive output uses its own directory, keeping old fixed-budget results available for read-only replotting.
