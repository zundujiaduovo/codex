# V13 scaled search, actual candidate diagnosis and configuration-LP bound

All runs here use Octave 9.4.0 on Linux, one BLAS thread, the fixed 64-user/64-beam/16-stream physical scene. These are cloud implementation checks, not the user's Windows MATLAB run and not multi-seed evidence of method superiority.

## Full search and implementation control

`legacy_scan_120s.log` runs all four methods with 500 SB steps, 32 trajectories/restarts, 12 polish moves and refresh every 2 rounds, using the frozen scalar polish. All four run to their soft 120 s budget and all exported stage schedules are independently verified by the original evaluator. This deliberately exposes the cost of simply increasing inner work: SB/Local each complete only 2 fairness rounds and return fairness 1.222568; Tabu returns 1.382834. These scores are not results of the final vectorized default.

`vector_scan_control_120s.log` reruns only SB and Local on exactly the same saved physical model, seed, initial-schedule policy, time budget and numerical search settings, replacing scalar polish with the mathematically equivalent vector implementation. Both complete 6 fairness rounds; SB returns 1.297797 and Local 1.289347. It is a single-seed implementation control with wall-time-sensitive outcomes, not a claim that SB beats Tabu. Source defaults now use vectorized polish for both methods. `profile_control.csv` includes round counts and measured inner times. No earlier baseline is relabeled as a new paired experiment.

## Global fairness upper bound

`fairness_bound_components.csv` and the trace show no-interference upper 14.360061, uniform cardinality upper 4.221238 and configuration-LP dual upper 3.048144. The LP solve is time limited; its valid dual upper is retained, rather than calling the restricted master value an upper bound or claiming original integer optimality. `independent_dual_check.log` recomputes the stored prices using the separate original-model cardinality upper-bound function (3.04814424723), confirming the reported outward value (3.04814425098). The remaining gap to feasible methods is still substantial.

## Candidate audit

`candidate_scores.csv` covers 32 frozen-state original Tabu-neighborhood probes and 16 genuinely recorded Tabu accepted improving actions from the full stressed-profile run; `maxReferencesPerPhase=1`, at most 8 retained candidates per reference and 8 actual moves per phase. This diagnostic run finishes within its 60 s cap.

Of these 48 sampled actions, 15 improve original fairness but have a nonpositive original price-weighted gain. The 16 recorded Tabu actions, scored counterfactually with fresh touching proxies and borrowed final SB prices, include 8 proxy ranking reversals (4 in phase 1, of which one increases fairness; 4 in phase 2). These are not falsely labeled actual SB rejections. The online frozen SB/Local probes show price misalignment or outer-selection/coordination evidence; no positive known-candidate shortfall against recorded inner proposals is witnessed in this sample. Missing inner information for counterfactual Tabu moves remains NaN. This does not prove that an inner solver is globally optimal.

`independent_candidate_check.log` independently re-evaluates all 48 original/proxy witnesses, with maximum weighted-gain discrepancy 8.88e-15. `candidate_diagnosis.png` renders the MATLAB-exported figure specification; phase/reference/weight provenance remains in CSV. Sample counts include related solver states and are not independent statistical error rates.

## Checks and preservation

`regression.log`, `final_targeted.log` and `real64_tests.log` cover independent integer enumeration, a known fractional LP optimum, risk margins, incomplete solves, hand-calculated price/proxy/inner classification examples, actual snapshot logging, exact legacy/vector group and RNG equivalence, 64-user 16-stream polish checks, both-stage fairness preservation and exported schedule re-evaluation. Existing V12 method/benchmark/diagnostic/certificate tests pass. GUI opening is mocked; scientific PNGs are rendered with Matplotlib.

`readonly_diagnosis.log` checks that an older saved benchmark is upgraded and analyzed in its own diagnosis directory while the original benchmark bytes are unchanged. All 9 frozen V8 files still match their historical snapshot. The downloadable source archive contains none of these result data.
