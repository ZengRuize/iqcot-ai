# E040-A D1 Immediate Add

Date: 2026-06-29

## Hypothesis

This run evaluates the E040-A `20A -> 40A` external load-current rise with initial two active phases and a local active-phase add policy. The supervisor gates IQCOT request/Ton parameter paths and never commands QH/QL gates or external load slew.

## Model Copy Path

`E:/Desktop/codex/models/derived/E040A_D1_immed_add_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Variant

`D1_immediate_two_to_four_add`

## Key Parameters

- `I_add_high = 30 A`
- `dwell_time = 0 us`
- `new_phase_ramp_time = 0 us`
- `current_limit_guard = 55 A/phase`
- `active Lambda = disabled`

## Metrics

| Variant | Success | N init | N final | Add accepts | Overshoot mV | Undershoot mV | Final err mV | Real imb A | Phase err | Dropped REQ | Current limit | Ton usage | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| D1 | 1 | 2 | 4 | 1 | 0 | 802.746 | -269.941 | 0.189786 | 0.120482 | 0 | 0 | 0 | pending |

## Per-Run Classification Hint

`pending`
