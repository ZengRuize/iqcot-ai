# E030-R1 C4d Ripple/Phase-Aware Projection

Date: 2026-06-29

## Hypothesis

This run retunes the fixed-four-phase `a_S` projection under one external DCR mismatch pattern at `40A`. The mismatch is a plant perturbation, not an AI action. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R1_C4d_projection_retune_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R1_C4d_ripple_phase_aware_projection`

## Projection Parameters

- `K_T = 5e-09`
- `T_trim_max = 25 ns`
- `projection_mode = 4`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Max imbalance A | RMS imbalance A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C4d | 1 | 0.313793 | 0.265373 | 15.2172 | -58.1561 | 0.865968 | 353 | 0 | 4.12679E-10 | 0 | 0.613443 | tradeoff_or_guard_issue |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4d_ripple_phase_aware_phase_triggers.csv`

## Per-Run Classification Hint

`tradeoff_or_guard_issue`
