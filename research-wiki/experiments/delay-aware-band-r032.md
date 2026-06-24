# Experiment: R032 delay-aware B_epsilon^sw band projection

## ID

`exp:delay-aware-band-r032`

## Purpose

将 R031 最小 held-out 派生 Simulink 结果整理为可部署风格的 `q_phi/r_hat/B_epsilon^sw` 接口，并生成下一轮小矩阵验证计划。

## Inputs

- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_family_summary.csv`

## Outputs

- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`
- `E:/Desktop/codex/output/iqcot_r032_candidate_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_band_rules.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_replay.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_report.md`
- `E:/Desktop/codex/output/figures/fig43_r032_delay_aware_band.svg`

## Result

R032 expands R031 into `40` candidate risk rows.  Band decisions are plant-admissible `12`, candidate-only `20`, blocked `8`.  Known-context replay gives fitted band projection mean regret `0.000`, dense fallback `0.337`, direct proxy override `1.107`, and nearest-tau LOTO stress `0.589`.

## Boundary

The `0.000` fitted replay is not an independent generalization proof.  The stronger scientific point is that nearest-tau interpolation fails on non-smooth boundaries, so the supervisor should use short-horizon event risk prediction and dense fallback, not direct proxy override.
