# R037 Short-Horizon `r_hat` Predictor Prototype

## Scope

R037 does not run new `.slx` simulations.  It consolidates R031/R033/R034/R036
derived-Simulink rows for `20A/score_settle005` into a deployable-style risk
view.  Inputs are limited to context/candidate features:
`target_load_A`, `load_drop_norm`, `alpha_settle`, `tau_AI`, `delay_events`,
`candidate T_slew`, `candidate_minus_dense_us`, and a `q_phi` folded-band prior
computed from current local evidence.  Skip, settling and phase labels are
switching-replay outputs, not online inputs.

## Dataset

- Rows: `51`
- Delays: `0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 5 us`
- Candidate slopes: `30, 38, 46, 50, 54, 58, 66 us`

## Leave-One-Delay Risk Check

| risk_label | tp | tn | fp | fn | precision | recall | f1 | accuracy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| skip | 5 | 26 | 10 | 10 | 0.333 | 0.333 | 0.333 | 0.608 |
| settling | 15 | 21 | 9 | 6 | 0.625 | 0.714 | 0.667 | 0.706 |
| phase | 1 | 43 | 1 | 6 | 0.500 | 0.143 | 0.222 | 0.863 |
| any_unsafe | 26 | 11 | 6 | 8 | 0.812 | 0.765 | 0.788 | 0.725 |

This is a deliberately small local predictor.  The most useful number is not
classification accuracy by itself, but whether the risk gate blocks obvious
bad candidates such as `66us` and long-settling/skip rows while preserving the
near-best folded candidates.  Any miss should be treated as a request for more
boundary validation, not as a reason to claim deployment readiness.

## Policy Replay

| tau_ai_us | oracle_slew_us | dense_slew_us | dense_regret | qphi_prior_slew_us | qphi_prior_regret | r037_slew_us | r037_regret | r037_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0.500 | 50.000 | 30.000 | 0.516 | 50.000 | 0.000 | 50.000 | 0.000 | qphi_prior_passes_rhat |
| 0.750 | 30.000 | 30.000 | 0.000 | 30.000 | 0.000 | 30.000 | 0.000 | qphi_prior_is_dense |
| 1.000 | 38.000 | 30.000 | 2.338 | 38.000 | 0.000 | 38.000 | 0.000 | qphi_prior_passes_rhat |
| 1.250 | 46.000 | 30.000 | 2.843 | 46.000 | 0.000 | 46.000 | 0.000 | qphi_prior_passes_rhat |
| 1.500 | 50.000 | 30.000 | 2.171 | 50.000 | 0.000 | 50.000 | 0.000 | qphi_prior_passes_rhat |
| 1.750 | 54.000 | 30.000 | 2.175 | 54.000 | 0.000 | 54.000 | 0.000 | qphi_prior_passes_rhat |
| 2.000 | 30.000 | 30.000 | 0.000 | 46.000 | 0.181 | 30.000 | 0.000 | dense_inclusive_foldback_guard |
| 3.000 | 30.000 | 30.000 | 0.000 | 30.000 | 0.000 | 30.000 | 0.000 | qphi_prior_is_dense |
| 5.000 | 30.000 | 30.000 | 0.000 | 30.000 | 0.000 | 30.000 | 0.000 | qphi_prior_is_dense |

Mean regret summary over the current local contexts:

- dense fallback: `1.116`
- folded `q_phi` prior: `0.020`
- R037 representative projection: `0.000`
- posterior safe upper-bound with the same risk gate: `0.054`

The risk gate rejects the observed oracle in `1` contexts.  If
this number is nonzero, it is evidence that the current `r_hat` is still a
calibration prototype rather than a final predictor.

## Projection Rules

| rule_id | condition | action | reason |
| --- | --- | --- | --- |
| R037-1 | T_slew >= 66us | block direct override | R030/R033/R031 rows repeatedly show skip or long-settling risk for 66us |
| R037-2 | candidate far from q_phi folded center and r_hat predicts skip/settling/phase risk | reject candidate and fall back to dense or nearest low-risk candidate | R034/R036 failures occur on both short-delay skip edge and long-slew settling edge |
| R037-3 | dense fallback itself has predicted skip/phase risk in the folded transition window | allow local folded candidate after dense-paired evidence | R036 shows 30us fallback loses at tau=1.25/1.75us due to skip/phase risk |
| R037-4 | tau_AI around 2us and dense fallback has low risk | keep dense fallback unless new paired validation proves otherwise | R031/R035 keep 30us at tau=2us although R034 transition probes are close |

## Minimal Extrapolation Plan

| r037_case_id | tau_ai_us | candidate_ref_slew_us | reason |
| --- | --- | --- | --- |
| R037_0001 | 1.250 | 42 | check left robustness between 38us near-tie and 46us R036 commit |
| R037_0002 | 1.250 | 44 | check slope into 46us R036 commit |
| R037_0003 | 1.750 | 52 | check slope into 54us R036 commit |
| R037_0004 | 1.750 | 56 | check right robustness beyond 54us R036 commit |
| R037_0005 | 2.000 | 42 | check fold-back boundary before 46us transition probe |
| R037_0006 | 2.000 | 44 | check fold-back boundary before 46us transition probe |
| R037_0007 | 2.000 | 48 | check 46/50us near-tie corridor against 30us fallback |
| R037_0008 | 1.500 | 46 | check center-pocket left neighbor not covered by R033 anchor |
| R037_0009 | 1.500 | 54 | check center-pocket right neighbor not covered by R033 anchor |

## Boundary

R037 supports the interface shape `q_phi -> r_hat -> B_epsilon^sw`, but it does
not prove a global `T_slew` optimum, hardware safety, or neural-network
AI-in-loop superiority.  AI remains a supervisory parameter scheduler; the
IQCOT inner event loop is unchanged.
