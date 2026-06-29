# E040-S0 S3 Guarded Shed With Residual/Relock/a_S

Date: 2026-06-30

## Hypothesis

S0 tests whether a mild external `40A -> 20A` load drop can shed from four phases to the corrected two-phase `[1,3]` mapping without REQ loss, inactive-phase requests, residual-current violation, or post-shed order error. The supervisor never commands gates or load-current slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040S0_S3_resid_as_iqcot_20260629.slx`

## Scheduler Audit CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s3_residual_as_scheduler_audit.csv`

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
| S3 | 1 | 4 | 3.79065 | 34 | 1.48593 | 19.1326 | -3.37124 | 9.58001 | 4.01163 | 1 | 0.992308 | 0 | 0 | 6.792 | pending |

## Per-Run Classification Hint

`pending`
