# E030-R3 C4a Ideal-Calibrated Projection

Date: 2026-06-29

## Hypothesis

This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R3_C4a_cal_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R3_C4a_ideal_calibrated_projection`

## Projection Parameters

- `K_T = 2.2e-09`
- `fallback_K_T = 0`
- `T_trim_max = 25 ns`
- `projection_mode = 1`
- `sense_gain_pattern = [1.05 0.95 1.05 0.95]`
- `g_hat_pattern = [1.05 0.95 1.05 0.95]`
- `sense_confidence = HIGH`
- `calibration_enable = 1`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Real max imb A | Sensed max imb A | Est IL1 A | Est IL2 A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | No-harm | Confidence | Cal | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| R3-C4a_cal | 1 | 0.020618 | 0.523013 | 10.0692 | 10.0511 | 8.58179 | -5.24904 | 0.371231 | 352 | NaN | NaN | HIGH | 1 | NaN | NaN | pending |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c4a_ideal_calibrated_phase_triggers.csv`

## Per-Run Classification Hint

`pending`
