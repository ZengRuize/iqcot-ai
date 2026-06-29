# E040-A D2 Guarded Add With Frozen a_S

Date: 2026-06-29

## Hypothesis

This run evaluates the E040-A `20A -> 40A` external load-current rise with initial two active phases and a local active-phase add policy. The supervisor gates IQCOT request/Ton parameter paths and never commands QH/QL gates or external load slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040A_D2_guard_add_as_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Variant

`D2_guarded_add_with_frozen_aS`

## Key Parameters

- `I_add_high = 30 A`
- `dwell_time = 2 us`
- `new_phase_ramp_time = 4 us`
- `current_limit_guard = 55 A/phase`
- `active Lambda = disabled`

## Metrics

| Variant | Success | N init | N final | Add accepts | Overshoot mV | Undershoot mV | Final err mV | Real imb A | Phase err | Dropped REQ | Current limit | Ton usage | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| D2 | 1 | 2 | 4 | 1 | 0 | 810.494 | -319.35 | 0.394051 | 0.170732 | 0 | 0 | 0.216193 | pending |

## Per-Run Classification Hint

`pending`
