# V12 changed objective: uncapped lexicographic fairness

Primary: maximize min_i G_i/q_i with no cap at 1. Secondary: maximize sum_i G_i while every ratio remains >= the attained stage-1 level.

Global original-model fairness interval: [1.81116317597, 1.82034650613]; status time_limit; gap target met 0. Extra certificate schedules are separate from method scores.

| Method | Search seed | Stage-1 fairness | Final fairness | Preserved floor | Final service (Mbit/period) | Stage-1 confirmed within certificate tolerance |
|---|---:|---:|---:|---:|---:|---:|
| original_tabu | 71669974 | 1.81116318 | 1.81116318 | 1.81116318 | 102.563908 | 0 |
| sb_v12_lexicographic | 71669974 | 1.43845949 | 1.44769627 | 1.43845949 | 100.998134 | 0 |
| local_v12_lexicographic | 71669974 | 1.60126521 | 1.60126521 | 1.60126521 | 100.073343 | 0 |

Fairness is the primary comparison. Total service at different attained floors solves different conditional problems; do not rank it as one common throughput objective.
A time-limited stage-1 result is an attained feasible fairness value, not a proven global maximum unless the fairness certificate closes its gap to the stated tolerance.
V10/V11 optimized full-QoS-then-sum service and their scores/bounds are not reused as V12 lexicographic optimality evidence.
