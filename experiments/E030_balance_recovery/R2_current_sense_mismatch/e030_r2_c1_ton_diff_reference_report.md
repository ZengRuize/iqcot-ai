# E030-R2 C1 Ton-Diff Reference

Date: 2026-06-29

## Hypothesis

This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R2_C1_current_sense_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R2_C1_ton_diff_reference`

## Projection Parameters

- `K_T = 5e-09`
- `T_trim_max = 25 ns`
- `projection_mode = 0`
- `sense_gain_pattern = [1.05 0.95 1.05 0.95]`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Real max imb A | Sensed max imb A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C1 | 1 | 0.475724 | 0.141896 | 15.0557 | -58.8678 | 0.871935 | 353 | 0 | 4.12679E-10 | 0 | 5.71434 | 0.573661 | ton_diff_reference |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c1_ton_diff_reference_phase_triggers.csv`

## Per-Run Classification Hint

`ton_diff_reference`
