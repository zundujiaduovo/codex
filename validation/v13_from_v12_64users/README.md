# V13 based on V12: validation evidence

Runtime: Octave 9.4.0 on Linux; OPENBLAS_NUM_THREADS=1, OMP_NUM_THREADS=1.
This is a release/integration check, not the default 120-second performance experiment.

- `v13_smoke.log`: `test_leo_v13` builds the real K=64, NB=64, L=16 model, with the fixed `reference64` layout, 16 RF chains, 10 W/stream and 160 W total-power limit. All 1280 user-resource pairs were available. It tests hard acceptance of 16 distinct-beam users and rejection of 17; all four methods complete, receive the same initial schedule, preserve their attained stage-1 floors, and pass original-model re-evaluation of BOTH stage CSV schedules. V13 figure specs are exported. Resuming reuses the pair without changing its bytes; V12 cannot load the same directory as its own experiment.
- Smoke settings: 20 s/method, at most one outer round per phase, 10 SB steps, 2 SB trajectories, 2 Local restarts, zero Monte Carlo samples; certificate search time zero, so the returned fairness interval is intentionally loose. Small time budgets can be exceeded by indivisible setup/check operations. These smoke scores do not characterize the default settings or establish relative method performance.
- `regression.log`: existing physical/numerical model checks, V12 uncapped objective/strict floor/original-model certificate tests, V12 diagnostics and exact restricted-block controls, installation checks, and V12/V13 three-window viewer checks pass. GUI opening is mocked; Windows MATLAB GUI execution is not exercised in this Linux test.
- `python3 tools/check_v8_snapshot.py`: all 9 frozen V8 sources match the historical snapshot after namespace reversal.

Run the main experiment in MATLAB with `RUN_V13_64_USERS`. The default protocol uses 120 s/method, the V12 SB/Local configurations, the original certificate budgets and independent fading validation; it saves a separate V13 dataset and opens three four-method figures.
