# E040-S1 Staged Shed-Handoff Protocol

Date: 2026-06-30

## Purpose

Implement and validate the smallest local staged-shed handoff that addresses the E040-S0 failure mechanism:

```text
The controller attempted to remove phases before those phases were unloaded and before the remaining phases could safely carry the load.
```

This document now records the executed S1-R0/S1-R2/S1-R3 preflight and the guard rules used for that run.

## Executed Result

```text
date: 2026-06-30
classification: MODEL_CONFIRMED
metrics: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
summary: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
derived models:
  models/derived/E040S1_R0_fixed4_iqcot_20260630.slx
  models/derived/E040S1_R2_transfer_drain_iqcot_20260630.slx
  models/derived/E040S1_R3_commit_relock_iqcot_20260630.slx
```

Key local S1-R3 metrics:

```text
N_active_final = 2
actual_active_phase_set_final = 1010
shed_commit_count = 1
fallback_4ph_count = 0
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_shed = 0
current_limit_hit = false
residual_current_check = pass
peak_undershoot = 0.641487 mV
final_Vout_error = 1.65264 mV
```

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

## Executed Variants

```text
S1-R0:
  fixed four-phase reference.

S1-R1:
  immediate shed reference from E040-S0, retained only as failure baseline.

S1-R2:
  staged load-share transfer + disabled-phase drain,
  no final active-set commit; used as the interpretability gate before R3.

S1-R3:
  staged transfer + drain + atomic shed commit + two-phase order relock.

S1-R4 optional:
  S1-R3 + conservative post-shed a_S recovery using C1low or C4a_conf only.
```

`S1-R4` remains unrun. Do not run `S1-R4` unless a separate protocol is written from the confirmed S1-R3 state:

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
phase_gate_enable1..4
```

`phase_gate_enable1..4` is a deterministic active-phase safety projection used to tri-state candidate disabled phases after per-phase residual-current qualification. It is not an AI gate command.

## Run Order Used

1. Audit baseline wiring and required signals.
2. Create a derived model copy through MATLAB APIs.
3. Add observability for state, commit, fallback, residual, scheduler audit, and conservative a_S gating.
4. Build `S1-R0` and verify it reproduces the fixed four-phase reference.
5. Build `S1-R2` and verify staged transfer/drain can delay commit safely.
6. Build `S1-R3` only after `S1-R2` produces interpretable transfer/drain logs.
7. Stop after `S1-R3`; do not run `S1-R4` in this chunk.

## Minimum Pass Criteria

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
