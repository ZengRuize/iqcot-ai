# R033 Delay-Band Derived-Simulink Validation

## Scope

R033 post-processes the completed R032 31-row delayed-reference validation
matrix.  All cases use the derived model
`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
through the R027 runner adapter.  No original `.slx` file is modified and no
`.slx` XML is edited.

This is derived-Simulink evidence for a supervisory `T_slew` scheduler.  It is
not hardware validation, not a global `T_slew` optimum proof, and not evidence
that AI replaces the IQCOT inner loop.

## Headline

- Completed rows: `31` over `7` validation contexts.
- Non-dense candidates are best in `4/7` contexts.
- The `66us` negative-control probe appears in `3` contexts with mean
  regret `1.186`; it remains unsafe as a direct override.

## Context Summary

| target_label | objective | tau_ai_us | best_slew_us | best_role | dense_regret | non_dense_best_slew_us | non_dense_best_role | non_dense_minus_dense_score | negative_66_regret |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | 2.000 | 32.000 | near_tie_probe | 0.058 | 32.000 | near_tie_probe | -0.058 | nan |
| 10A | score_settle010 | 3.000 | 33.000 | near_tie_probe | 0.176 | 33.000 | near_tie_probe | -0.176 | nan |
| 20A | base | 1.000 | 86.000 | direct_override_probe | 0.061 | 86.000 | direct_override_probe | -0.061 | nan |
| 20A | base | 3.000 | 80.000 | dense_fallback | 0.000 | 82.000 | intermediate_probe | 0.024 | nan |
| 20A | score_settle005 | 0.750 | 30.000 | dense_fallback | 0.000 | 50.000 | intermediate_band | 0.051 | 2.324 |
| 20A | score_settle005 | 1.500 | 50.000 | intermediate_band | 2.171 | 50.000 | intermediate_band | -2.171 | 0.644 |
| 20A | score_settle005 | 3.000 | 30.000 | dense_fallback | 0.000 | 38.000 | intermediate_band | 0.301 | 0.591 |

## Candidate-Role Summary

| candidate_role | n_rows | mean_context_regret | max_context_regret | mean_settle_time_us | mean_skip_count | best_context_count |
| --- | --- | --- | --- | --- | --- | --- |
| direct_override_probe | 2 | 0.132 | 0.263 | 17.582 | 0.000 | 1 |
| near_tie_probe | 6 | 0.139 | 0.347 | 16.924 | 1.000 | 2 |
| dense_fallback | 7 | 0.352 | 2.171 | 9.182 | 0.429 | 3 |
| intermediate_band | 9 | 0.399 | 0.868 | 5.964 | 0.000 | 1 |
| intermediate_probe | 4 | 0.946 | 1.896 | 15.889 | 0.500 | 0 |
| negative_control_66us | 3 | 1.186 | 2.324 | 9.202 | 0.333 | 0 |

## Refined Rules

| target_label | objective | tau_region_us | r033_observation | refined_rule | deployment_status |
| --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | around 2 | 32us is best at tau=2us, with 30us only 0.058 score worse and 34us only 0.033 worse | treat 30-34us as a delay-sensitive near-tie candidate band; do not claim a sharp optimum | candidate band; dense fallback remains acceptable |
| 10A | score_settle010 | around 3 | 33us is best at tau=3us; dense 30us has 0.176 regret | 33us remains plant-admissible in the long-delay near-tie band | locally supported by derived Simulink |
| 20A | base | around 1 | 86us is base-score best by 0.061 over 80us, while 82/84us introduce skip; 86us also has longer settling | keep 86us as objective-dependent candidate-only probe; do not globally unblock it | needs settling-aware confirmation before plant commit |
| 20A | base | around 3 | 80us is best; 82/84us are near, 86us is worse | retain 80us fallback and keep 82/84us as low-risk ranking probes | fallback supported |
| 20A | score_settle005 | around 0.75 | 30us is best; 38/50us are close, 58us worsens settling, 66us has skip and 2.324 regret | use 30us fallback; keep 38/50us candidate-only; block 66us | negative control confirms large-jump risk |
| 20A | score_settle005 | around 1.5 | 50us is best; 30us has skip and 2.171 regret; 66us has long settling and 0.644 regret | add a transition pocket allowing 50us near tau=1.5us, with 38us as backup candidate | locally supported; still not a global rule |
| 20A | score_settle005 | around 3 | 30us is best; 38us is second; 50/58/66us show longer settling | retain dense 30us fallback; keep 38us as a ranking probe only | fallback supported |

## Interpretation

`10A/score_settle010` supports a small delay-sensitive near-tie band rather
than a point optimum: `32us` is best at `tau=2us`, while `33us` is best at
`tau=3us`.  The margins are small and skip is still observed, so the paper
should describe this as a local candidate band.

`20A/base` is objective-sensitive.  At `tau=1us`, `86us` has the best base
score by a small margin, but `82/84us` introduce skip and `86us` also has
longer settling than `80us`.  At `tau=3us`, `80us` is best.  Therefore the
previous hard block on `86us` should soften only to an objective-dependent
candidate probe, not to a general plant-commit rule.

`20A/score_settle005` is the most useful calibration motif.  At `tau=0.75us`,
`30us` remains best and `66us` is a strong negative control with skip.  At
`tau=1.5us`, `50us` becomes best and `30us` skips, revealing a transition
pocket.  At `tau=3us`, the dense `30us` fallback is again best.  This supports
a delay-aware band with a narrow `50us` transition pocket, while continuing to
block `66us` as a direct override.
