# R034 Full Transition-Pocket Derived-Simulink Validation

## Scope

R034 completes all `20` planned transition-pocket cases for
`20A/score_settle005` and combines them with the R033 `tau_AI=1.5us` anchor.
All simulations use the derived Simulink model via the delayed-reference
runner.  This is not hardware validation and not a global optimum proof.

## Main Finding

The fixed `50us` transition-pocket hypothesis is rejected as a general local
rule.  The observed best sequence is:

```text
tau_AI: 1.00 -> 1.25 -> 1.50 -> 1.75 -> 2.00 us
T_best: 38   -> 46   -> 50   -> 54   -> 46 us
```

At `tau=1.0us`, all candidates from `46us` upward trigger skip and are about
`2.15` to `2.25` score worse than `38us`.  At `tau=2.0us`, `46us` is best and
`50us` is nearly tied (`0.027` regret), while `54/58us` suffer long settling.
Thus the transition set is a folded local band: it rises through `46/50/54us`
and folds back to `46/50us` as settling risk dominates.

## Context Summary

| tau_ai_us | n_candidates | best_slew_us | best_score | best_source | best_skip_count_est | best_settle_time_us | second_best_slew_us | second_best_regret | bad_skip_candidates | long_settle_candidates |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1.000 | 5 | 38.000 | 2.221 | R034_full_validation | 0.000 | 0.938 | 46.000 | 2.155 | 4 | 0 |
| 1.250 | 5 | 46.000 | 2.146 | R034_full_validation | 0.000 | 0.938 | 38.000 | 0.189 | 1 | 3 |
| 1.500 | 3 | 50.000 | 2.141 | R033_anchor_tau1p5 | 0.000 | 0.938 | 38.000 | 0.205 | 0 | 1 |
| 1.750 | 5 | 54.000 | 2.142 | R034_full_validation | 0.000 | 0.938 | 38.000 | 0.159 | 1 | 2 |
| 2.000 | 5 | 46.000 | 2.274 | R034_full_validation | 0.000 | 0.938 | 50.000 | 0.027 | 0 | 2 |

## Candidate Summary

| candidate_slew_label | n_rows | mean_regret | max_regret | mean_skip | mean_settle_us | best_count |
| --- | --- | --- | --- | --- | --- | --- |
| 38us | 5 | 0.172 | 0.305 | 0.000 | 0.938 | 1 |
| 54us | 4 | 0.915 | 2.165 | 0.250 | 6.041 | 1 |
| 46us | 4 | 1.048 | 2.155 | 0.500 | 0.938 | 2 |
| 58us | 5 | 1.062 | 2.251 | 0.200 | 9.540 | 0 |
| 50us | 5 | 1.106 | 2.568 | 0.400 | 5.016 | 1 |

## Folded-Band Policy

| tau_ai_us | observed_best_us | projected_commit_us | projection_matches_observed | second_best_us | second_best_regret | rule |
| --- | --- | --- | --- | --- | --- | --- |
| 1.000 | 38.000 | 38.000 | True | 46.000 | 2.155 | left edge: short candidate only; avoid 46us+ skip |
| 1.250 | 46.000 | 46.000 | True | 38.000 | 0.189 | rising edge: 46us validated at tau=1.25us |
| 1.500 | 50.000 | 50.000 | True | 38.000 | 0.205 | center anchor inherited from R033 |
| 1.750 | 54.000 | 54.000 | True | 38.000 | 0.159 | right edge: 54us validated at tau=1.75us |
| 2.000 | 46.000 | 46.000 | True | 50.000 | 0.027 | fold-back edge: 46us best, 50us near tie; avoid 54/58us settling |

## Interpretation

The result strengthens the PIS-IEK argument because it shows why a smooth
continuous action model is unsafe: the local best action changes with discrete
skip and settling regimes.  A deployable supervisor should output a candidate
band plus risk estimates, then project through `B_epsilon^sw`; it should not
blindly apply a fixed `50us` command or a monotonic tau interpolation.
