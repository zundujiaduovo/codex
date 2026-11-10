# V11 based on V10: actual Octave validation artifacts

The 20-seed / 120-second paired experiment and 160 fixed-subproblem pairs were executed in GNU Octave 9.4.0. Read RESULTS.md and ../../V11_VALIDATION.md for the measured results and certificate stopping status. The user-provided V10 Windows MATLAB run is documented separately in ../../V11_FROM_V10.md.

Recheck exported CSV pairing, binary schedule constraints, user QoS and recorded-time statistics from the repository root:

```bash
python3 tools/validate_v11_exports.py validation/v11_based_on_v10_octave
```

Reconstruct all 60 schedules and evaluate their ORIGINAL certified-service objectives and user QoS from the saved numerical model:

```matlab
addpath('matlab');
audit=run_leo_v11_verify_exports('validation/v11_based_on_v10_octave');
```

The latter check returned 60 verified schedules with maximum total-service error 0 bit. It does not optimize or use quadratic proxy scores. original_model.mat contains the frozen original model and protocol; CSV files contain all final schedules, users, time checkpoints, paired results, and certificate-node evidence. The per-seed raw search MAT files remain in the runtime results directory and are not duplicated here.

figures/ contains both scientific figures, a combined PDF and overview. These figures were rendered by Matplotlib from MATLAB/Octave JSON specifications; native Windows MATLAB FIG export was not executed in this cloud runtime. Source-only ZIP releases exclude this validation directory.
