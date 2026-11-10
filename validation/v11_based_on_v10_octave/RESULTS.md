# V11 based on V10: paired search results

Runtime: 9.4.0; platform: x86_64-pc-linux-gnu. Scene seed: 71669974; 20 search seeds; 120 s/method.

All scores are evaluated by the original certified-service model. The quadratic proxy generates search candidates only.

This repeats search randomness on ONE fixed physical model. It does not measure robustness across different user layouts.

Original-model optimum interval: [115.222388999, 115.223854601] Mbit/period; remaining certificate gap 0.001272%.

| Comparison | Valid/expected | SB wins/ties/losses | Mean delta (Mbit) | Pointwise 95% paired bootstrap CI | Holm sign p |
|---|---:|---:|---:|---:|---:|
| SB vs original_tabu | 20/20 | 0/0/20 | -6.450525 | [-6.722663, -6.177462] | 3.8147e-06 |
| SB vs local_v8_blockwise | 20/20 | 8/5/7 | 0.095273 | [-0.135250, 0.319001] | 1 |

Final returned scores follow the V10 soft-budget convention; exact-deadline differences are also in paired_statistics.csv.
Missing/failed/non-QoS runs remain missing. Reached-only median times must be read together with target success counts.
95% mean CIs are pointwise percentile bootstrap intervals, not simultaneous guarantees. The two primary sign tests use Holm correction.
Independent fading means and validation success frequencies are separate from the certified objective and its upper bound.
