# E030-R3 C0 Current-Sense Mismatch Baseline

Date: 2026-06-29

## Hypothesis

This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R3_C0_cal_guard_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R3_C0_iqcot_current_sense_mismatch`

## Projection Parameters

- `K_T = 0`
- `fallback_K_T = 0`
- `T_trim_max = 25 ns`
- `projection_mode = 0`
- `sense_gain_pattern = [1.05 0.95 1.05 0.95]`
- `g_hat_pattern = [1.05 0.95 1.05 0.95]`
- `sense_confidence = LOW`
- `calibration_enable = 0`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Real max imb A | Sensed max imb A | Est IL1 A | Est IL2 A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | No-harm | Confidence | Cal | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| R3-C0 | 1 | 0.036272 | 0.538006 | 9.96251 | 9.97348 | 1.13739 | -1.81159 | 0 | 340 | NaN | NaN | LOW | 0 | NaN | NaN | pending |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c0_current_sense_mismatch_phase_triggers.csv`

## Per-Run Classification Hint

`pending`
