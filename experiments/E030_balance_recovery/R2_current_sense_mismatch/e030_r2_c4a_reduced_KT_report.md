# E030-R2 C4a Reduced-KT Projection

Date: 2026-06-29

## Hypothesis

This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R2_C4a_current_sense_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R2_C4a_reduced_KT_projection`

## Projection Parameters

- `K_T = 2.2e-09`
- `T_trim_max = 25 ns`
- `projection_mode = 1`
- `sense_gain_pattern = [1.05 0.95 1.05 0.95]`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Real max imb A | Sensed max imb A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C4a | 1 | 0.317534 | 0.195376 | 8.60658 | -7.4593 | 0.401338 | 352 | 0 | 5.30483 | 0 | 3.67806 | 0.321621 | sensed_real_divergence |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c4a_reduced_KT_phase_triggers.csv`

## Per-Run Classification Hint

`sensed_real_divergence`
