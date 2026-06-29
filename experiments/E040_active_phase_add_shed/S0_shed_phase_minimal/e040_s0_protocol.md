# E040-S0 Protocol

Date: 2026-06-30

## Baseline Rule

Use the local ideal IQCOT baseline:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Do not edit the baseline or raw `.slx` XML. Derived copies are created under `models/derived/` through MATLAB/Simulink APIs.

## Variants

```text
S0:
  fixed four-phase reference, no shed

S1:
  immediate 4 -> 2 shed
  purpose: expose immediate shed risk

S2:
  guarded 4 -> 2 shed with dwell and post-reentry lockout
  residual current is measured but not enforced
  a_S disabled

S3:
  guarded 4 -> 2 shed with dwell, post-reentry lockout,
  residual-current qualification, corrected [1,3] two-phase remap,
  and frozen guarded a_S enabled only after shed/relock completion
```

S4 is not run in this first S0 chunk.

## Initial Local Parameters

```text
I_shed_low = 25 A
dwell_time = 3 us
post_reentry_shed_delay = 1 us
order_relock_window = 2 us
current_limit_guard = 55 A/phase
active Lambda = disabled
```

The residual-current threshold is computed from S0 fixed-four-phase `IL2` and `IL4` traces using the guard window:

```text
t in [t_load_step + dwell_time + post_reentry_shed_delay,
      t_load_step + dwell_time + post_reentry_shed_delay + 8 us]
```

The initial threshold is:

```text
residual_current_threshold =
    prctile(abs([IL2, IL4]) in guard window, 95) + 0.25 A
```

This is a waveform-derived local threshold, not a general design constant.

## Shed-State Audit Design

Each accepted scheduler event exports:

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
shed_state
```

The postprocess computes phase-order error from `REQ_accept1..4` and `physical_phase`, not from QH edges alone.

## Windowed Phase-Order Metrics

Windows:

```text
pre_shed: before shed_accept_time
during_shed: shed_accept_time to shed_accept_time + order_relock_window
post_shed: after shed_accept_time + order_relock_window
```

Before shed, the expected sequence is `[1,2,3,4]`. After shed, the expected sequence is `[1,3]`.

## Classification

Use `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`.

If S3 passes local integrity and does not worsen voltage/current behavior beyond the S0 reference, E040-S0 may claim only a local guarded shed integrity result. It still must not claim broad active-phase robustness, active Lambda, severe shed cases, efficiency gain, or hardware/HIL validation.
