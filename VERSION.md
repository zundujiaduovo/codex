# V17 — based on V16 4b5ea77

Branch: `leo-qos-v17-fairness-first-proxy-parallel-sb`.
Original tag: `v17-fairness-first-parallel64`.
GPU and memory fix tag: `v17-gpu64-memory-safe`.

GPU fix: 64 trajectories in one GPU matrix; CPU-double scores and acceptance; single/double dynamics; GPU/CPU controls.

Memory fix: no CPU pool in GPU mode, 4 workers in CPU fallback; resize reused pools; bounded detailed evidence; compact progress history; abort later methods after an OOM while retaining completed checkpoints.

Strict lexicographic incumbent retention; fairness promotions restart stage 1.
Shared original-model fairness escapes are counted separately from QUBO solving.
Counterfactual tangents, candidate-pool gain audits and frozen-pool tangent calibration.
64-trajectory CPU parallel bSB, repeated-repair caching, paired serial/parallel controls and bounded-search QUBO references.
Original-model certificates remain independent. See [V17_CHANGELOG.md](V17_CHANGELOG.md).
