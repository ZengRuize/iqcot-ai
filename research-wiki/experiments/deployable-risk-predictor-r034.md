# Experiment: R034 deployable risk predictor prototype

## ID

`exp:deployable-risk-predictor-r034`

## Purpose

Convert R033 boundary-validation evidence into an interpretable
`q_phi/r_hat/B_epsilon^sw` supervisory interface and a next validation matrix.

## Outputs

- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_grid.csv`
- `E:/Desktop/codex/output/iqcot_r034_policy_surface.csv`
- `E:/Desktop/codex/output/iqcot_r034_transition_pocket_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_predictor_report.md`
- `E:/Desktop/codex/output/figures/fig45_r034_deployable_risk_predictor.svg`

## Result

R034 proposes a deployable-style interface and generates `20` new
derived-Simulink validation cases.  It keeps `66us` blocked, treats
`20A/base/86us` as candidate-only, and creates a local `50us` transition pocket
for `20A/score_settle005` near `tau_AI=1.5us`.

## Boundary

Design/proposal evidence only until the generated validation plan is run.
Not hardware validation and not independent generalization proof.
