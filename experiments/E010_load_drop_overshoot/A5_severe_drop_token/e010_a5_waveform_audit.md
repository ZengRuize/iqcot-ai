# E010-A5 Waveform Audit

Date: 2026-06-30

Status: DESIGN_ONLY

## Purpose

This audit defines the signals required before E010-A5 can produce interpretable severe-drop claims. It is not a simulation result.

## Required Signal Availability Table

Future runs must create a per-variant signal availability CSV with:

```text
signal_name,is_available,notes
```

Required signals:

```text
Vout
Iload
IL1
IL2
IL3
IL4
IL_sense1
IL_sense2
IL_sense3
IL_sense4
REQ1
REQ2
REQ3
REQ4
REQ_accept1
REQ_accept2
REQ_accept3
REQ_accept4
REQ_reject_reason
QH1
QH2
QH3
QH4
QL1
QL2
QL3
QL4
phase_idx
Ton_cmd1
Ton_cmd2
Ton_cmd3
Ton_cmd4
Ton_actual1
Ton_actual2
Ton_actual3
Ton_actual4
active_HS_phase
Ton_trunc_i
Ton_saved_i
Lambda_i
area_int_i
a_O_state
severe_drop_detect
pulse_inhibit_state
area_hold_state
reentry_state
fallback_state
current_limit_hit
phase_order_error
burst_pulse_count_after_reentry
```

## Audit Windows

```text
early local peak: 0-2 us after load step
recovery peak: 2-12 us after load step
late recovery: 12-40 us after load step
late settling: 12-80 us after load step
final error window: final 10 us of simulation
```

## Required Event Audit

Future per-variant event audit CSV must include:

```text
event_index
time_us
a_O_state
REQ_in_phase
REQ_accept_phase
REQ_reject_reason
phase_idx_before
phase_idx_after
Ton_cmd_ns
Ton_actual_ns
area_int_i
Vout_mV
fallback_safe_active
fallback_reason
```

The audit must prove:

```text
no raw request is silently dropped
first reentry phase is phase-order valid
post-reentry burst pulse count is bounded
area_int_i does not force unstable reentry
fallback reason is logged if A5 is rejected
```

## Missing Signal Rule

Unavailable signals must be recorded. Metrics must not be fabricated from unavailable signals. Missing critical logging for Ton truncation, pulse inhibit, area hold/reset, reentry, or REQ audit requires `IMPLEMENTATION_ISSUE`.
