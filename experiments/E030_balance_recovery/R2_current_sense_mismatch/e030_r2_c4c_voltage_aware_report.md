# E030-R2 C4c Voltage-Aware Projection

Date: 2026-06-29

## Hypothesis

This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R2_C4c_current_sense_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R2_C4c_voltage_error_aware_projection`

## Projection Parameters

- `K_T = 5e-09`
- `T_trim_max = 25 ns`
- `projection_mode = 3`
- `sense_gain_pattern = [1.05 0.95 1.05 0.95]`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Real max imb A | Sensed max imb A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C4c | 1 | 0.432627 | 0.126599 | 7.54143 | -29.6157 | 0.681135 | 353 | 0 | 4.12679E-10 | 0 | 5.0425 | 0.365715 | sensed_real_divergence |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c4c_voltage_aware_phase_triggers.csv`

## Per-Run Classification Hint

`sensed_real_divergence`
