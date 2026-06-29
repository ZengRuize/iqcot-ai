# E040-S0 S2 Guarded Shed With Dwell/Lockout

Date: 2026-06-30

## Hypothesis

S0 tests whether a mild external `40A -> 20A` load drop can shed from four phases to the corrected two-phase `[1,3]` mapping without REQ loss, inactive-phase requests, residual-current violation, or post-shed order error. The supervisor never commands gates or load-current slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040S0_S2_guard_shed_iqcot_20260629.slx`

## Scheduler Audit CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s2_guarded_shed_scheduler_audit.csv`

## Residual Threshold

`9.93948 A`

95th percentile of abs(IL2,IL4) over 4.000-12.000 us after step plus 0.25 A; envelope95=9.68948 A

## Key Parameters

- `I_shed_low = 25 A`
- `dwell_time = 3 us`
- `post_reentry_shed_delay = 1 us`
- `order_relock_window = 2 us`
- `active Lambda = disabled`

## Metrics

| Variant | Success | N init | N final | Shed accept | Overshoot mV | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| S2 | 1 | 4 | 2 | 12 | 1.48593 | 543.833 | -500.714 | 9.58001 | 4.01163 | 1 | 0.265152 | 0 | 0 | NaN | pending |

## Per-Run Classification Hint

`pending`
