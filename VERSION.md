# V16 — based on V15 97afd6c

Branch: `leo-qos-v16-parallel64-until-convergence`.
Annotated version tag: `v16-parallel64-convergence`.

64 SB trajectories, actual CPU worker-pool parallel search; no time or outer-iteration cap for the four main search methods.
Empirical convergence is measured on the original objective over full iteration windows and is separate from global certification.
The latest normalized fairness coordination, joint blocks, trust-region candidate repair and original-service acceptance remain enabled.
Original-service branch-and-price certificates, checkpointing and controls are retained. Historical entries, bundles and results are removed from this branch.

See [V16_CHANGELOG.md](V16_CHANGELOG.md).
