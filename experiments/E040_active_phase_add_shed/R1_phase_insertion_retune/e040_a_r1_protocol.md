# E040-A-R1 Protocol

Date: 2026-06-29

## Baseline Rule

Use only this source model:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Do not edit the baseline model or raw `.slx` XML. Derived copies are created under `models/derived/`.

## Variants

```text
R1-D0:
  fixed two-phase reference using physical phases [1, 3]

R1-D1:
  immediate 2 -> 4 add with corrected event remap

R1-D2:
  guarded 2 -> 4 add with corrected event remap, dwell, and new-phase Ton ramp
  frozen a_S disabled until order/relock is valid

R1-D3:
  guarded 2 -> 4 add with corrected event remap, dwell, new-phase Ton ramp,
  and frozen guarded a_S enabled only after add/reentry/order relock completion
```

Do not include shed variants.

## Initial R1 Parameters

```text
I_add_high = 30 A
dwell_time = 1 us
new_phase_ramp_time = 2 us
new_phase_Ton_limit = 0.75 * Ton_nom
order_relock_window = 2 us
post_add_reentry_delay = 0.5 us
current_limit_guard = 55 A/phase
active Lambda = disabled
```

## Scheduler Remap Audit Design

For each accepted request event, audit:

```text
event_index
logical_slot
physical_phase
active_phase_set
REQ_in
REQ_accept
REQ_reject_reason
phase_idx_before
phase_idx_after
```

The MATLAB run script exports a compact event table per variant and computes phase-order metrics from accepted `REQ` events, not from `QH` edges alone. `QH` edges remain logged for waveform sanity.

## Windowed Phase-Order Metrics

Compute:

```text
phase_order_error_rate_pre_add
phase_order_error_rate_during_add
phase_order_error_rate_post_add
```

Windows:

```text
pre_add: before active_phase_transition_time
during_add: transition_time to transition_time + order_relock_window
post_add: after transition_time + order_relock_window
```

For fixed two-phase R1-D0, the two-phase sequence `[1, 3]` is used for the full post-step interval.

## Pass Criteria

Minimum pass:

```text
N_active_final == 4
phase_add_accept_count >= 1
dropped_REQ_count == 0
inactive_phase_REQ_count == 0
phase_order_error_rate_post_add == 0
current_limit_hit == 0
```

Preferred pass:

```text
peak_undershoot improves versus R1-D0
final_Vout_error improves versus R1-D0
real current imbalance does not worsen versus R1-D1
a_S does not enable before order relock completion
```

## Classification

Use `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`. If R1 remains `MODEL_REVISED`, do not run E040-S.
