# E010-A5 Severe-Drop a_O Protocol

Date: 2026-06-30

Status: DESIGN_ONLY

## Do Not Run Yet

This package defines the next smallest-useful validation. It does not contain simulation results.

Do not combine E010-A5 with:

```text
active-phase shedding
active Lambda
DCR mismatch
current-sense mismatch
broad parameter grids
severe active-phase load-rise/drop cases
```

## Fixed Case

```text
External load-current drop: 40A -> 1A
Active phases: fixed four-phase
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
Active-phase add/shed: disabled
```

Load current is an external disturbance. AI/table logic may observe load-step direction, magnitude, and estimated slew, but it must not command load-current slew.

## Required Run Order

1. Re-audit baseline wiring and available signals.
2. Create a derived model copy through MATLAB/Simulink APIs.
3. Add only A5 observability and projected supervisory logic to the derived copy.
4. Reproduce A5-C0 and A5-C4 first.
5. Stop after A5-C0/A5-C4 if logging or metrics are unreliable.
6. Only then test the smallest A5 candidate set: A5-T1, A5-T2, A5-T3, A5-T4.

## Future Variants

```text
A5-C0:
  original ideal IQCOT for 40A -> 1A.

A5-C4:
  previous A4 no-harm selector.

A5-T1:
  severe Ton truncation only.

A5-T2:
  severe Ton truncation + bounded one-pulse inhibit.

A5-T3:
  severe Ton truncation + bounded multi-pulse inhibit + area hold.

A5-T4:
  full A5 severe-drop token with controlled reentry and fallback guard.
```

## Initial Candidate Settings

These are evidence-local starting points, not final controller constants:

```text
DeltaI_drop_threshold_high = 30 A
multi_pulse_inhibit_count candidates = [1, 2, 3]
Tton_trunc_min_severe candidates = [40 ns, 60 ns, 80 ns]
Tton_trunc_window_severe candidates = [2 us, 4 us]
inhibit_time_severe candidates = [1.8 us, 3.0 us, 4.5 us]
reentry_band_down_severe candidates = [0.8 mV, 1.0 mV, 1.5 mV]
undershoot_budget_severe initial = 2.0 mV
late_settling_guard window = 12-80 us
```

The first execution should choose one conservative setting per variant instead of sweeping the full Cartesian grid.

## Required Logged Signals

```text
Vout
Iload
IL1..IL4
IL_sense1..IL_sense4
REQ1..REQ4
REQ_accept1..REQ_accept4
REQ_reject_reason
QH1..QH4
QL1..QL4
phase_idx
Ton_cmd1..4
Ton_actual1..4
Ton_trunc_i
Ton_saved_i
area_int_i
a_O_state
severe_drop_detected
active_HS_phase
Ton_trunc_active
Ton_trunc_count
pulse_inhibit_active
pulse_inhibit_count
inhibit_release_condition
area_hold_active
area_hold_count
area_reset_count
area_bleed_count
reentry_armed
controlled_reentry_active
controlled_reentry_Ton_limit
first_reentry_phase
first_reentry_Ton_ns
burst_pulse_limit_after_reentry
burst_pulse_count_after_reentry
current_limit_hit
fallback_safe_active
fallback_count
fallback_reason
```

If a signal is unavailable, document it in `e010_a5_waveform_audit.md`. Do not fabricate metrics.

## Pass Criteria

A5 is useful only if:

```text
peak_overshoot or recovery_peak improves versus A5-C0 and A5-C4
peak_undershoot penalty remains within undershoot_budget_severe
dropped_REQ_count == 0
phase_order_error_rate == 0
current_limit_hit == false
burst_pulse_count_after_reentry is bounded
final_Vout_error remains bounded
fallback does not loop
```

## Hard Fail

```text
undershoot penalty exceeds budget
reentry creates burst pulses
dropped_REQ_count > 0
phase_order_error_rate > 0
current_limit_hit == true
fallback loops occur
area_int_i corrupts reentry behavior
```

## Classification

```text
MODEL_CONFIRMED:
  A5 full token reduces severe-drop overshoot/recovery peak while staying within all guards.

MODEL_REVISED:
  A5 helps partially but needs revised inhibit count, reentry band, area policy, or fallback.

IMPLEMENTATION_ISSUE:
  Ton truncation, pulse inhibit, area hold/reset, reentry logging, REQ audit, or postprocess is unreliable.

CLAIM_DOWNGRADED:
  A5 cannot improve 40A -> 1A without unacceptable undershoot or reentry instability in the local model.
```
