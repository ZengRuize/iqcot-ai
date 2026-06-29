# E040-S0 Waveform And Scheduler Audit

Date: 2026-06-30

## Signal Boundary

The run requires voltage/load/current/gate logs plus `REQ_raw1..4`, `REQ_accept1..4`, `phase_idx`, `logical_slot`, `physical_phase_selected`, `active_phase_set`, `N_active`, shed-state, residual-current, order-relock, and delayed a_S logs.

All variants produced metric rows and per-variant scheduler audit CSV files.

## Residual Threshold

Threshold selected from S0 fixed-four-phase waveform: `9.93948 A`.

95th percentile of abs(IL2,IL4) over 4.000-12.000 us after step plus 0.25 A; envelope95=9.68948 A

## Metrics Snapshot

| Variant | Success | N init | N final | Shed accept | Overshoot mV | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| S0 | 1 | 4 | 4 | 0 | 1.13166 | 0.45125 | 0.698733 | NaN | NaN | NaN | NaN | 0 | 0 | NaN | fixed_four_phase_reference |
| S1 | 1 | 4 | 2 | 1 | 0.944587 | 663.614 | -624.357 | 14.6727 | 8.91282 | 0 | 0 | 0 | 0 | NaN | current_limit_hit |
| S2 | 1 | 4 | 2 | 12 | 1.48593 | 543.833 | -500.714 | 9.58001 | 4.01163 | 1 | 0.265152 | 0 | 0 | NaN | current_limit_hit |
| S3 | 1 | 4 | 3.79065 | 34 | 1.48593 | 19.1326 | -3.37124 | 9.58001 | 4.01163 | 1 | 0.992308 | 0 | 0 | 6.792 | shed_not_accepted |

## Scheduler Audit Files

- `S0`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s0_fixed4_scheduler_audit.csv`
- `S1`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s1_immediate_shed_scheduler_audit.csv`
- `S2`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s2_guarded_shed_scheduler_audit.csv`
- `S3`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s3_residual_as_scheduler_audit.csv`

## Wave Samples

- `S0`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s0_fixed4_wave_sample.csv`
- `S1`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s1_immediate_shed_wave_sample.csv`
- `S2`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s2_guarded_shed_wave_sample.csv`
- `S3`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_s3_residual_as_wave_sample.csv`

## Classification

`MODEL_REVISED`
