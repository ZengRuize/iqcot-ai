# E040-A-R1 D1 Immediate Add With Corrected Remap

Date: 2026-06-29

## Hypothesis

R1 tests whether corrected `[1,3] -> [1,2,3,4]` phase insertion can preserve IQCOT event order for an external `20A -> 40A` load-current disturbance. The supervisor never commands QH/QL gates or load-current slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040R1_D1_remap_add_iqcot_20260629.slx`

## Scheduler Audit CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d1_remap_add_scheduler_audit.csv`

## Key Parameters

- `I_add_high = 30 A`
- `dwell_time = 0 us`
- `new_phase_ramp_time = 0 us`
- `new_phase_Ton_limit = 1 * Ton_nom`
- `order_relock_window = 0 us`
- `post_add_reentry_delay = 0.5 us`
- `active Lambda = disabled`

## Metrics

| Variant | Success | N init | N final | Add accept | Under mV | Final err mV | Real imb A | Post order err | Dropped REQ | Inactive REQ | Current limit | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-D1 | 1 | 2 | 4 | 1 | 801.96 | -270.375 | 0.245432 | 0 | 0 | 0 | 0 | NaN | pending |

## Per-Run Classification Hint

`pending`
