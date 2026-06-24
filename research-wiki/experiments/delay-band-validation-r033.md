# Experiment: R033 delay-band derived-Simulink validation

## ID

`exp:delay-band-validation-r033`

## Purpose

Validate the R032 delay-aware `B_epsilon^sw` boundary on a small derived
Simulink delayed-reference matrix.

## Inputs

- `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_band_rules.csv`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

## Outputs

- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_role_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_rule_update.csv`
- `E:/Desktop/codex/output/figures/fig44_r033_delay_band_validation.svg`

## Result

All `31` planned derived-Simulink cases completed.  Non-dense candidates are
best in `4/7` contexts.  The important corrections are:

- `10A/score_settle010`: `32us` wins at `tau=2us`, `33us` wins at `tau=3us`; treat as a near-tie band.
- `20A/base`: `86us` wins only for base objective at `tau=1us`; keep it candidate-only.
- `20A/score_settle005`: `50us` wins at `tau=1.5us`, but `30us` wins at `0.75us` and `3us`; keep `66us` blocked.

## Boundary

Derived Simulink only.  Not hardware validation, not neural-network AI-in-loop,
and not a global optimum proof.
