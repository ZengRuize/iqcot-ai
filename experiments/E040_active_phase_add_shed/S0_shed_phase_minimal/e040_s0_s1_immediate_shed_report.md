# E040-S0 S1 Immediate Shed

Date: 2026-06-30

## Hypothesis

S0 tests whether a mild external `40A -> 20A` load drop can shed from four phases to the corrected two-phase `[1,3]` mapping without REQ loss, inactive-phase requests, residual-current violation, or post-shed order error. The supervisor never commands gates or load-current slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040S0_S1_immed_shed_iqcot_20260629.slx`

## Scheduler Audit CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s1_immediate_shed_scheduler_audit.csv`

## Residual Threshold

`9.93948 A`

95th percentile of abs(IL2,IL4) over 4.000-12.000 us after step plus 0.25 A; envelope95=9.68948 A

## Key Parameters

- `I_shed_low = 25 A`
- `dwell_time = 0 us`
- `post_reentry_shed_delay = 0 us`
- `order_relock_window = 0 us`
- `active Lambda = disabled`

## Metrics

| Variant | Success | N init | N final | Shed accept | Overshoot mV | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| S1 | 1 | 4 | 2 | 1 | 0.944587 | 663.614 | -624.357 | 14.6727 | 8.91282 | 0 | 0 | 0 | 0 | NaN | pending |

## Per-Run Classification Hint

`pending`
