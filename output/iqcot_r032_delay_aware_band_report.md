# R032 Delay-Aware `B_epsilon^sw` Band Projection

## Scope

R032 converts the completed R031 minimal held-out derived-Simulink result into
a deployable-style short-horizon risk interface.  It does not run or edit any
`.slx` model.  The result is a known-context consistency design plus a next
validation matrix, not hardware validation and not a proof that `T_slew` has a
global optimum.

The proposed online shape is:

```text
q_phi(z_k, T_slew, tau_AI) -> score/ranking candidate
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]

T_slew,plant =
  Proj_{B_epsilon^sw(z_k,tau_AI,r_hat,T_dense)}(T_slew,candidate)
```

AI remains a supervisory parameter scheduler.  It does not replace the IQCOT
inner loop and does not output gate commands.

## Candidate Risk Table

R032 expands the R031 combined table into `40` candidate rows.
Band decisions are: plant-admissible `12`, candidate-only
`20`, blocked `8`.  The blocked set includes the
`20A/score_settle005 -> 66us` direct override and the `20A/base -> 86us`
override.

## Policy Replay

| policy | deployability | n_contexts | mean_regret | max_regret | mean_margin_vs_dense | non_dense_selected_count | mean_r_hat_total_risk | zero_regret_context_count |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| r032_delay_aware_band_projection | calibrated_candidate | 9 | 0.000 | 0.000 | -0.337 | 3 | 0.100 | 9 |
| r031_best_intermediate_only | nondeployable_upper_candidate | 9 | 0.143 | 0.532 | -0.194 | 9 | 0.422 | 3 |
| dense_fallback | deployable_baseline | 9 | 0.337 | 2.338 | 0.000 | 0 | 0.050 | 6 |
| nearest_tau_loto_predictor | leave_one_tau_stress | 9 | 0.589 | 2.189 | 0.251 | 4 | 0.317 | 4 |
| direct_proxy_override | negative_control | 9 | 1.107 | 2.793 | 0.769 | 9 | 0.761 | 0 |

The fitted R032 projection has known-context mean regret
`0.000` on the R031 replay table, while dense fallback is
`0.337` and direct proxy override is
`1.107`.  This is only a calibration consistency result.
The leave-one-tau nearest-neighbor stress policy has mean regret
`0.589`, showing that simple tau interpolation can fail
near the non-smooth skip/reentry boundaries.  R031 best-intermediate-only has
mean regret `0.143`, so intermediate slopes need dense
fallback and risk projection.

## Delay-Aware Band Rules

| target_label | objective | dense_fallback_us | candidate_band_us | plant_commit_rule | blocked_rule | r032_status |
| --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | 30.000 | [30, 33] | tau_AI >= 3us -> 33us; otherwise dense 30us | do not directly commit 32/33us at tau_AI around 1us without fresh evidence | delay-sensitive near-tie band; calibrated from R031 only |
| 20A | base | 80.000 | [80, 84] candidate-only | default dense 80us; 82/84us are ranking probes | block 86us direct override | dense fallback retained; intermediate candidates need more switching evidence |
| 20A | score_settle005 | 30.000 | [38, 58] with dense fallback | tau<0.75us -> 50us; 0.75<=tau<1.5us -> 38us; otherwise dense 30us | block 66us unless a future short-horizon predictor certifies low skip/settling risk | large-jump negative sample converted into bounded intermediate band |

## Next Derived-Simulink Validation Plan

The generated next matrix contains `31` rows.  It targets transition
boundaries rather than repeating completed R031 points.  It should be run only
on derived models under `E:/Desktop/codex/output/simulink_iek`.

| r032_case_id | target_label | objective | tau_ai_us | candidate_ref_slew_us | priority | reason |
| --- | --- | --- | --- | --- | --- | --- |
| R032_0001 | 10A | score_settle010 | 2.000 | 30.000 | 2 | resolve 30/33us transition boundary |
| R032_0002 | 10A | score_settle010 | 2.000 | 32.000 | 2 | resolve 30/33us transition boundary |
| R032_0003 | 10A | score_settle010 | 2.000 | 33.000 | 2 | resolve 30/33us transition boundary |
| R032_0004 | 10A | score_settle010 | 2.000 | 34.000 | 2 | resolve 30/33us transition boundary |
| R032_0005 | 10A | score_settle010 | 3.000 | 30.000 | 2 | resolve 30/33us transition boundary |
| R032_0006 | 10A | score_settle010 | 3.000 | 32.000 | 2 | resolve 30/33us transition boundary |
| R032_0007 | 10A | score_settle010 | 3.000 | 33.000 | 2 | resolve 30/33us transition boundary |
| R032_0008 | 10A | score_settle010 | 3.000 | 34.000 | 2 | resolve 30/33us transition boundary |
| R032_0009 | 20A | base | 1.000 | 80.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0010 | 20A | base | 1.000 | 82.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0011 | 20A | base | 1.000 | 84.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0012 | 20A | base | 1.000 | 86.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0013 | 20A | base | 3.000 | 80.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0014 | 20A | base | 3.000 | 82.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0015 | 20A | base | 3.000 | 84.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |
| R032_0016 | 20A | base | 3.000 | 86.000 | 3 | test whether base-objective 82/84us ever justifies replacing 80us fallback |

## Interpretation

R032 refines the claim boundary rather than expanding it.  The strongest
allowable statement is that R031/R032 support a delay-aware local band with
dense fallback and a short-horizon risk-prediction interface.  They do not
show that the proxy or AI is globally better than dense-anchor tables, and
they do not replace hardware or HIL validation.
