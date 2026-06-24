# R034 Transition-Pocket Partial Derived-Simulink Validation

## Scope

This report combines the executed R034 transition-pocket chunks at
`tau_AI=1.25us` and `1.75us`, then compares them with the R033 `tau_AI=1.5us`
anchor.  It is a partial derived-Simulink validation, not hardware validation
and not proof of global `T_slew` optimality.

## Key Result

The original R034 fixed `50us` transition-pocket hypothesis is too narrow.
The observed local best points form a tentative moving ridge:

- `tau_AI=1.25us -> 46us`
- `tau_AI=1.50us -> 50us` from R033 anchor
- `tau_AI=1.75us -> 54us`

At `tau_AI=1.25us`, `50us` triggers skip and has regret `2.568`, while `46us`
is best.  At `tau_AI=1.75us`, `54us` is best, while `46us` triggers skip and
`50/58us` suffer longer settling.  This supports a moving transition ridge,
not a fixed pocket.

## Context Summary

| target_label | objective | tau_ai_us | n_candidates | best_slew_us | best_source | best_score | best_settle_time_us | best_skip_count_est | second_best_slew_us | second_best_regret |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20A | score_settle005 | 1.250 | 5 | 46.000 | R034_partial_validation | 2.146 | 0.938 | 0.000 | 38.000 | 0.189 |
| 20A | score_settle005 | 1.500 | 3 | 50.000 | R033_anchor_tau1p5 | 2.141 | 0.938 | 0.000 | 38.000 | 0.205 |
| 20A | score_settle005 | 1.750 | 5 | 54.000 | R034_partial_validation | 2.142 | 0.938 | 0.000 | 38.000 | 0.159 |

## Tentative Ridge Model

| tau_ai_us | best_slew_us | best_source | ridge_formula_us | ridge_error_us | status |
| --- | --- | --- | --- | --- | --- |
| 1.250 | 46.000 | R034_partial_validation | 46.000 | 0.000 | new derived-Simulink point |
| 1.500 | 50.000 | R033_anchor_tau1p5 | 50.000 | 0.000 | inherited R033 anchor |
| 1.750 | 54.000 | R034_partial_validation | 54.000 | 0.000 | new derived-Simulink point |

## Remaining Validation Plan

| r034_case_id | tau_ai_us | candidate_ref_slew_us | priority |
| --- | --- | --- | --- |
| R034_0001 | 1.000 | 38.000 | 2 |
| R034_0002 | 1.000 | 46.000 | 2 |
| R034_0003 | 1.000 | 50.000 | 2 |
| R034_0004 | 1.000 | 54.000 | 2 |
| R034_0005 | 1.000 | 58.000 | 2 |
| R034_0016 | 2.000 | 38.000 | 2 |
| R034_0017 | 2.000 | 46.000 | 2 |
| R034_0018 | 2.000 | 50.000 | 2 |
| R034_0019 | 2.000 | 54.000 | 2 |
| R034_0020 | 2.000 | 58.000 | 2 |

## Interpretation

R034 now gives stronger evidence that the safe transition set is mode-aware and
delay-sensitive.  A practical supervisor should not commit a fixed `50us`
action merely because `tau_AI` is near the transition region.  A better
deployable interface is:

```text
T_ridge(tau_AI) ≈ 26 + 16*tau_AI us, clipped to the verified candidate band,
then projected by skip/settling risk and dense fallback.
```

The formula is only a local hypothesis from three points.  The remaining
`tau_AI=1.0us` and `2.0us` rows are needed before writing it as more than a
candidate predictor.
