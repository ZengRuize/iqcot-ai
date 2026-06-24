# R031 Minimal Held-Out Derived-Simulink Validation

## Scope

This report post-processes the completed R031 minimal validation chunks.  It
combines the `22` new R031 intermediate-slope cases with matching R030 dense
baseline and original proxy rows.  All runs use the derived
`four_phase_iek_dynamic_load_refslew.slx` model and delayed `Iph_ref_ts`
profiles.  This is derived-Simulink evidence, not hardware validation.

## Family Summary

| candidate_family | n_rows | mean_context_regret | max_context_regret | mean_objective_score | mean_undershoot_mV | mean_settle_time_us | mean_skip_count | best_context_count |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| r030_dense_baseline | 9 | 0.337 | 2.338 | 4.523 | 1.800 | 9.802 | 0.444 | 6 |
| r031_intermediate_candidate | 22 | 0.490 | 2.251 | 4.339 | 1.648 | 10.397 | 0.409 | 3 |
| r030_original_proxy | 9 | 1.107 | 2.793 | 5.293 | 1.780 | 15.810 | 0.667 | 0 |

## Context Summary

R031 best intermediate candidates beat the dense baseline in `3/9`
contexts and beat the original R030 proxy in `8/9` contexts.
The mean R031-best minus dense score is `-0.194`; negative means R031 improves
over dense, positive means it is worse.  Best-family counts are `{'r030_dense_baseline': 6, 'r031_intermediate_candidate': 3}`.

| target_label | objective | tau_ai_us | best_family | best_slew_us | dense_score | proxy_score | r031_best_slew_us | r031_best_score | r031_minus_dense_score | best_skip_count_est | best_settle_time_us |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | 1.000 | r030_dense_baseline | 30.000 | 9.916 | 10.607 | 33.000 | 10.447 | 0.532 | 1.000 | 9.664 |
| 10A | score_settle010 | 5.000 | r031_intermediate_candidate | 33.000 | 10.520 | 10.678 | 33.000 | 10.340 | -0.180 | 1.000 | 18.804 |
| 20A | base | 0.500 | r030_dense_baseline | 80.000 | 2.042 | 2.321 | 82.000 | 2.157 | 0.115 | 0.000 | 14.402 |
| 20A | base | 2.000 | r030_dense_baseline | 80.000 | 1.989 | 2.176 | 84.000 | 2.196 | 0.207 | 0.000 | 14.412 |
| 20A | base | 5.000 | r030_dense_baseline | 80.000 | 4.067 | 4.214 | 84.000 | 4.069 | 0.001 | 1.000 | 19.262 |
| 20A | score_settle005 | 0.500 | r031_intermediate_candidate | 50.000 | 2.785 | 4.846 | 50.000 | 2.269 | -0.516 | 0.000 | 0.938 |
| 20A | score_settle005 | 1.000 | r031_intermediate_candidate | 38.000 | 4.559 | 2.871 | 38.000 | 2.221 | -2.338 | 0.000 | 0.938 |
| 20A | score_settle005 | 2.000 | r030_dense_baseline | 30.000 | 2.093 | 4.886 | 50.000 | 2.301 | 0.208 | 0.000 | 0.938 |
| 20A | score_settle005 | 5.000 | r030_dense_baseline | 30.000 | 2.739 | 5.034 | 58.000 | 2.961 | 0.222 | 0.000 | 9.498 |

## Interpretation

- `10A/score_settle010`: `31/33us` remain delay-sensitive.  At `tau_AI=1us`
  the dense `30us` baseline remains better, while at `tau_AI=5us` the `33us`
  intermediate candidate improves over dense.  This supports a conservative,
  delay-aware near-tie band rather than a fixed proxy override.
- `20A/base`: intermediate `82/84us` reveals delay-sensitive behavior but does
  not materially beat the dense `80us` baseline in these contexts.  Among the
  intermediate candidates, `82us` is best at `0.5us`, while `84us` is best at
  `2/5us`; this supports a delay-aware band and blocks direct `86us` proxy
  override.
- `20A/score_settle005`: the safer intermediate band is strongly delay
  dependent.  `50us` is best at `0.5/2us`, `38us` is best at `1us`, and
  `58us` is best at `5us`.  This partially rehabilitates intermediate slopes,
  but does not re-admit the original `66us` proxy without short-horizon risk
  prediction.

## Claim Boundary

R031 minimal validation improves the empirical design of `B_epsilon^sw`, but it
does not prove global `T_slew` optimality, does not prove AI/proxy can replace
the IQCOT inner loop, and does not constitute hardware validation.  The safest
claim is that `B_epsilon^sw` should be delay-aware and should admit
intermediate candidate bands only after derived switching replay or a validated
short-horizon event-risk predictor.
