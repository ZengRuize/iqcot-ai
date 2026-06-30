# E040-S1 R0 Fixed Four-Phase Reference

Date: 2026-06-30

## Hypothesis

E040-S1 tests whether staged load-share transfer and disabled-phase drain can avoid the E040-S0 failure mode, where phases were removed before they were safely unloaded. The supervisor does not command gates or external load-current slew.

## Derived Model

`E:/Desktop/codex/models/derived/E040S1_R0_fixed4_iqcot_20260630.slx`

## Fixed Case

`40A -> 20A`, initial four phases, target mask `1010`, nominal DCR/sense gains, active Lambda disabled.

## Key Guard Parameters

- `shed_transfer_window = 6 us`
- `disabled_phase_drain_timeout = 6 us`
- `residual_current_threshold = 1.5 A`
- `remaining_phase_current_limit_guard = 50 A`
- `shed_undershoot_budget = 45 mV`
- `active Lambda = disabled`

## Output Files

- Scheduler audit CSV: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_scheduler_audit.csv`
- Signal availability CSV: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_signal_availability.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_wave_sample.csv`

## Metrics

| Variant | Success | N init | N final | Active final | Commit | Fallback | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | Hint |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| S1-R0 | 1 | 4 | 4 | 1111 | 0 | 0 | 0.45125 | 0.698733 | 3.68592 | 9.25788 | fail | NaN | 0 | 0 | pending |

## Per-Run Classification Hint

`pending`
