# E040-S1 Staged Shed-Handoff Protocol

Date: 2026-06-30

## Purpose

Design the smallest future validation that addresses the E040-S0 failure mechanism:

```text
The controller attempted to remove phases before those phases were unloaded and before the remaining phases could safely carry the load.
```

This document is a protocol. It does not report simulation results.

## Fixed Case

```text
External load-current drop: 40A -> 20A
Initial active phases: 4
Target active phases: 2
Target active phase set: [1,3] or mask [1,0,1,0]
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
```

Do not change the load step. Do not add DCR mismatch, current-sense mismatch, severe load-drop cases, or broad 1/2/4 grids.

## Required Baseline Handling

All future model changes must start from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Rules:

- do not modify the baseline model directly;
- create derived copies through MATLAB/Simulink APIs;
- never edit raw `.slx` XML;
- retain IQCOT as the deterministic fast pulse/event generator;
- AI/table supervisor may change only low-dimensional projected parameters;
- AI/table supervisor may not command gates or external load-current slew.

## Future Variants

```text
S1-R0:
  fixed four-phase reference.

S1-R1:
  immediate shed reference from E040-S0, retained only as failure baseline.

S1-R2:
  staged load-share transfer + disabled-phase drain,
  but no final commit unless all guards pass.

S1-R3:
  staged transfer + drain + atomic shed commit + two-phase order relock.

S1-R4 optional:
  S1-R3 + conservative post-shed a_S recovery using C1low or C4a_conf only.
```

Do not run `S1-R4` unless `S1-R3` satisfies the local integrity gate:

```text
N_active_final == 2
phase_order_error_rate_post_shed == 0
inactive_phase_REQ_count == 0
dropped_REQ_count == 0
current_limit_hit == false
residual_current_check == pass
```

## New Guard Variables

The future implementation must expose these guard variables:

```text
shed_transfer_rate
shed_transfer_window
max_transfer_Ton_trim
remaining_phase_current_limit_guard
disabled_phase_drain_timeout
residual_current_threshold
shed_commit_boundary_policy
post_commit_order_relock_window
post_shed_aS_delay
shed_fallback_enable
shed_fallback_reason
```

Discrete state observability:

```text
shed_state
shed_transfer_progress
disabled_phase_current_sum
commit_armed
commit_done
fallback_4ph_triggered
fallback_reason
```

## Future Run Order

1. Audit baseline wiring and required signals.
2. Create a derived model copy through MATLAB APIs.
3. Add observability for state, commit, fallback, residual, scheduler audit, and conservative a_S gating.
4. Build `S1-R0` and verify it reproduces the fixed four-phase reference.
5. Build `S1-R2` and verify staged transfer/drain can delay commit safely.
6. Build `S1-R3` only after `S1-R2` produces interpretable transfer/drain logs.
7. Consider `S1-R4` only if `S1-R3` passes all hard integrity gates.

## Minimum Future Pass Criteria

```text
N_active_final == 2
actual_active_phase_set_final == [1,3]
shed_commit_count == 1
fallback_4ph_count == 0
dropped_REQ_count == 0
inactive_phase_REQ_count == 0
phase_order_error_rate_post_shed == 0
current_limit_hit == false
residual_current_check == pass
peak_undershoot does not exceed the S0 fixed-four-phase reference by an unacceptable budget
final_Vout_error remains bounded
```

## Hard Fail Criteria

```text
N_active_final is fractional or not exactly 2
fallback loops occur repeatedly
accepted events target inactive phases
phase_order_error_rate_post_shed > 0
current_limit_hit == true
residual_current_check == fail
a_S enables before commit/order relock/residual checks pass
```

## Classification Rule

Future execution must classify the result as one of:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

Use `MODEL_CONFIRMED` only if the staged handoff mechanism passes the integrity gates and voltage/current limits in the specified local case.
