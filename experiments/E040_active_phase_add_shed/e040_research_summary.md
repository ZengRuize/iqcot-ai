# E040 Active-Phase Research Summary

Date: 2026-06-29

## Hypothesis

E040-A tests whether a local guarded active-phase add transition can move from two to four active phases during a moderate external `20A -> 40A` load-current rise without voltage disruption, REQ loss, phase-order error, current-limit hit, or post-add current-sharing instability.

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Model Copy Paths

- `D0`: `E:/Desktop/codex/models/derived/E040A_D0_fixed2_iqcot_20260629.slx`
- `D1`: `E:/Desktop/codex/models/derived/E040A_D1_immed_add_iqcot_20260629.slx`
- `D2`: `E:/Desktop/codex/models/derived/E040A_D2_guard_add_as_iqcot_20260629.slx`
- `D3`: `E:/Desktop/codex/models/derived/E040A_D3_guard_add_conf_iqcot_20260629.slx`

## External Load And Active-Phase Case

`20A -> 40A`, initial active phases `2`, target active phases `4`, nominal DCR, nominal current-sense gains, active Lambda disabled.

## Frozen a_S Selector

The E030-R3 local guarded selector is used after add/reentry. In this first nominal-sensing chunk, calibrated `C4a`-like Ton-difference recovery is allowed only after the add ramp reaches reentry completion. Active Lambda remains disabled.

## Metrics Table

Metrics CSV: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/e040_metrics.csv`

| Variant | Success | N init | N final | Add accepts | Overshoot mV | Undershoot mV | Final err mV | Real imb A | Phase err | Dropped REQ | Current limit | Ton usage | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| D0 | 1 | 2 | 2 | 0 | 0 | 907.223 | -903.504 | 0.170176 | 0.142857 | 0 | 0 | 0 | fixed_two_phase_reference |
| D1 | 1 | 2 | 4 | 1 | 0 | 802.746 | -269.941 | 0.189786 | 0.120482 | 0 | 0 | 0 | phase_order_error |
| D2 | 1 | 2 | 4 | 1 | 0 | 810.494 | -319.35 | 0.394051 | 0.170732 | 0 | 0 | 0.216193 | phase_order_error |
| D3 | 1 | 2 | 4 | 1 | 0 | 810.494 | -319.35 | 0.394051 | 0.170732 | 0 | 0 | 0.216193 | phase_order_error |

## Interpretation

D0 is the fixed two-phase reference with final `N_active = 2`.

- `D1`: final `N_active = 4`, add accepts = 1, dropped REQ = 0, phase-order error = 0.120482, hint = `phase_order_error`.
- `D2`: final `N_active = 4`, add accepts = 1, dropped REQ = 0, phase-order error = 0.170732, hint = `phase_order_error`.
- `D3`: final `N_active = 4`, add accepts = 1, dropped REQ = 0, phase-order error = 0.170732, hint = `phase_order_error`.

## Failure Or Trade-Off Analysis

The active-phase transition occurred but failed at least one integrity or bound check.

## Classification

`MODEL_REVISED`

## Claim Boundary

This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad active-phase robustness, E040-S shed behavior, active Lambda control, global efficiency improvement, or severe load-rise recovery.

## Next Smallest Useful Experiment

Retune dwell/ramp/current-sharing guard parameters and rerun the same E040-A chunk before E040-S.
