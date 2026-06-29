# E040-S0 Hypothesis

Date: 2026-06-30

## Scope

E040-S0 runs only the mild shed-phase case:

```text
external load-current step: 40A -> 20A
initial active phases: 4
target active phases: 2
power-stage DCR: nominal
current-sense gains: nominal
active Lambda: disabled
baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The load-current drop is an external disturbance. The supervisor observes the load drop and may propose low-dimensional active-phase scheduling tokens, but it does not command the load profile or QH/QL gate signals.

## Hypothesis

Immediate `4 -> 2` shedding is expected to expose residual-current and reentry risk. A guarded shed sequence should delay the `4 -> 2` transition until mild load-drop protection is no-op/complete, dwell and post-reentry delay have elapsed, residual current in phases 2 and 4 is below an evidence-local threshold, and the two-phase `[1,3]` order can be relocked without REQ loss.

Minimum local pass conditions:

```text
N_active_final = 2
phase_shed_accept_count >= 1
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_shed = 0
current_limit_hit = 0
residual_current_check = pass
```

## Residual-Current Threshold Principle

The threshold is selected from the S0 fixed-four-phase waveform, not chosen as a universal constant. The run script measures `IL2` and `IL4` after the mild load drop, over the local guard window beginning after dwell plus post-reentry delay, then uses the observed shed-candidate current envelope with a small margin as the initial S0 threshold.

This threshold is evidence-local to the ideal derived model and the `40A -> 20A` case.

## Boundary

E040-S0 can only validate one local mild shed-phase point. It cannot prove broad active-phase robustness, arbitrary 1/2/4 scheduling, severe `40A -> 1A` or `120A -> 10A` shed behavior, active Lambda control, efficiency improvement, hardware, HIL, board-level, or silicon behavior.
