# R034 Deployable Risk Predictor Prototype

## Scope

R034 converts the R033 boundary-validation results into a lightweight,
deployable-style `q_phi/r_hat/B_epsilon^sw` interface.  It does not run or edit
`.slx` files.  AI remains a supervisory parameter scheduler that proposes
candidate scores and risk estimates; IQCOT remains the inner loop.

The script output is a calibrated rule/risk interface, not a trained neural
network, not hardware validation, and not proof of a global `T_slew` optimum.

## Outputs

- Risk grid rows: `87`
- Policy-surface rows: `15`
- Next validation-plan rows: `20`
- B-epsilon labels: `{'candidate_only': 36, 'near_tie_band': 15, 'dense_fallback': 11, 'blocked': 9, 'transition_pocket': 9, 'objective_probe': 6, 'plant_admissible': 1}`

## Policy Surface

| target_label | objective | tau_ai_us | q_phi_candidate_us | q_phi_candidate_label | candidate_total_risk | plant_commit_us | plant_commit_label | deployment_status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | 1.000 | 32.000 | near_tie_band | 0.430 | 30.000 | near_tie_band | fallback_or_validation_needed |
| 10A | score_settle010 | 2.000 | 32.000 | near_tie_band | 0.430 | 30.000 | near_tie_band | fallback_or_validation_needed |
| 10A | score_settle010 | 3.000 | 33.000 | plant_admissible | 0.462 | 33.000 | plant_admissible | plant_admissible_with_current_evidence |
| 10A | score_settle010 | 5.000 | 33.000 | near_tie_band | 0.462 | 30.000 | near_tie_band | fallback_or_validation_needed |
| 20A | base | 1.000 | 86.000 | objective_probe | 0.634 | 80.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | base | 3.000 | 80.000 | dense_fallback | 0.250 | 80.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 0.500 | 50.000 | candidate_only | 0.264 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 0.750 | 50.000 | candidate_only | 0.260 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 1.000 | 50.000 | candidate_only | 0.236 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 1.250 | 50.000 | transition_pocket | 0.170 | 30.000 | dense_fallback | fallback_or_validation_needed |
| 20A | score_settle005 | 1.500 | 50.000 | transition_pocket | 0.124 | 50.000 | transition_pocket | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 1.750 | 50.000 | transition_pocket | 0.170 | 30.000 | dense_fallback | fallback_or_validation_needed |
| 20A | score_settle005 | 2.000 | 50.000 | candidate_only | 0.236 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 2.500 | 50.000 | candidate_only | 0.264 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |
| 20A | score_settle005 | 3.000 | 50.000 | candidate_only | 0.264 | 30.000 | dense_fallback | plant_admissible_with_current_evidence |

## Transition-Pocket Validation Plan

| r034_case_id | target_label | objective | tau_ai_us | candidate_ref_slew_us | priority |
| --- | --- | --- | --- | --- | --- |
| R034_0001 | 20A | score_settle005 | 1.000 | 38.000 | 2 |
| R034_0002 | 20A | score_settle005 | 1.000 | 46.000 | 2 |
| R034_0003 | 20A | score_settle005 | 1.000 | 50.000 | 2 |
| R034_0004 | 20A | score_settle005 | 1.000 | 54.000 | 2 |
| R034_0005 | 20A | score_settle005 | 1.000 | 58.000 | 2 |
| R034_0006 | 20A | score_settle005 | 1.250 | 38.000 | 1 |
| R034_0007 | 20A | score_settle005 | 1.250 | 46.000 | 1 |
| R034_0008 | 20A | score_settle005 | 1.250 | 50.000 | 1 |
| R034_0009 | 20A | score_settle005 | 1.250 | 54.000 | 1 |
| R034_0010 | 20A | score_settle005 | 1.250 | 58.000 | 1 |
| R034_0011 | 20A | score_settle005 | 1.750 | 38.000 | 1 |
| R034_0012 | 20A | score_settle005 | 1.750 | 46.000 | 1 |
| R034_0013 | 20A | score_settle005 | 1.750 | 50.000 | 1 |
| R034_0014 | 20A | score_settle005 | 1.750 | 54.000 | 1 |
| R034_0015 | 20A | score_settle005 | 1.750 | 58.000 | 1 |
| R034_0016 | 20A | score_settle005 | 2.000 | 38.000 | 2 |
| R034_0017 | 20A | score_settle005 | 2.000 | 46.000 | 2 |
| R034_0018 | 20A | score_settle005 | 2.000 | 50.000 | 2 |
| R034_0019 | 20A | score_settle005 | 2.000 | 54.000 | 2 |
| R034_0020 | 20A | score_settle005 | 2.000 | 58.000 | 2 |

## Interpretation

R034 makes the R033 correction deployable in shape.  The main rule is not
simple tau interpolation.  For `20A/score_settle005`, the predictor creates a
narrow `50us` transition pocket near `tau_AI=1.5us`, keeps `30us` as fallback
outside the pocket, and blocks `66us`-class large jumps.  The generated R034
validation plan probes `tau_AI=1.0/1.25/1.75/2.0us` with
`38/46/50/54/58us` candidates to test whether the pocket is real or just a
single-point artifact.

Boundary: the policy-surface table should be described as a deployable
interface proposal and next-experiment generator.  It should not be described
as independent generalization or hardware evidence.
