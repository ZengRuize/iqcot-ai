# E030-R1 C4a Reduced-KT Projection

Date: 2026-06-29

## Hypothesis

This run retunes the fixed-four-phase `a_S` projection under one external DCR mismatch pattern at `40A`. The mismatch is a plant perturbation, not an AI action. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_R1_C4a_projection_retune_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Controller Variant

`R1_C4a_reduced_KT_projection`

## Projection Parameters

- `K_T = 2.2e-09`
- `T_trim_max = 25 ns`
- `projection_mode = 1`
- `V_error_budget = 15 mV`
- `ripple_budget = 8 mV`

## Metrics

| Variant | Success | Max imbalance A | RMS imbalance A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C4a | 1 | 0.416996 | 0.411139 | 8.12771 | -3.60374 | 0.404392 | 353 | 0 | 9.14654 | 0 | 0.362552 | pareto_candidate |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4a_reduced_KT_phase_triggers.csv`

## Per-Run Classification Hint

`pareto_candidate`
