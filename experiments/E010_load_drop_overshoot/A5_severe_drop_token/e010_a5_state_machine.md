# E010-A5 Severe-Drop a_O State Machine

Date: 2026-06-30

Status: DESIGN_ONLY

## Purpose

This state machine defines the observable severe-drop `a_O` protection sequence for a future fixed-four-phase `40A -> 1A` validation. It is a design artifact, not a simulation result.

The AI/table supervisor may propose `a_O_severe`, but only the safety-projected token may reach IQCOT parameter scheduling. The IQCOT inner loop remains the deterministic event generator. A5 does not command high-side or low-side gates directly and does not command external load-current slew.

## State List

```text
NORMAL
SEVERE_DROP_DETECTED
ACTIVE_HS_TRUNCATE
PULSE_INHIBIT
AREA_HOLD
REENTRY_ARMED
CONTROLLED_REENTRY
BALANCE_RECOVERY
FALLBACK_SAFE
```

## State Definitions

| State | Purpose | Exit Condition |
|---|---|---|
| `NORMAL` | Ordinary IQCOT operation | Load-drop branch with severe magnitude |
| `SEVERE_DROP_DETECTED` | Latch event context and classify severe-drop branch | Projection accepts A5 path or fallback |
| `ACTIVE_HS_TRUNCATE` | Reduce residual high-side on-time through projected Ton scheduling | Truncation window complete or no active HS pulse |
| `PULSE_INHIBIT` | Reject bounded number of unsafe early reentry requests | Inhibit count/time and release guards pass |
| `AREA_HOLD` | Hold, clamp, bleed, or reset area integrator to avoid burst reentry | Area state is within safe range |
| `REENTRY_ARMED` | Wait for voltage, undershoot, phase-order, current, and area guards | Controlled reentry can begin |
| `CONTROLLED_REENTRY` | Reintroduce accepted pulses with Ton and burst limits | Recovery is stable or fallback guard trips |
| `BALANCE_RECOVERY` | Enable conservative post-reentry balance recovery only | Balance guard done |
| `FALLBACK_SAFE` | Return to A4/no-op style safety behavior | Stable baseline-like behavior |

## NORMAL

Normal IQCOT operation. No A5 action is active.

## SEVERE_DROP_DETECTED

Enter when:

```text
branch == load_drop
DeltaI_drop = Iload_before - Iload_after
DeltaI_drop >= DeltaI_drop_threshold_high
```

For the target case:

```text
Iload_before = 40A
Iload_after = 1A
DeltaI_drop = 39A
DeltaI_drop_threshold_high candidate = 30A
```

Latch:

```text
t_drop
Iload_before
Iload_after
DeltaI_drop
Vout_at_drop
IL1..IL4_at_drop
active_HS_phase
area_int_i_at_drop
```

The threshold is evidence-local, not universal.

## ACTIVE_HS_TRUNCATE

If a high-side pulse is active, truncate current Ton through projected Ton scheduling:

```text
Ton_truncated_ns = max(Tton_trunc_min_severe, projected_remaining_Ton_ns)
Ton_saved_ns = Ton_original_ns - Ton_truncated_ns
```

This is not a direct gate command.

Log:

```text
active_HS_phase
Ton_original_ns
Ton_truncated_ns
Ton_saved_ns
Ton_trunc_count
```

## PULSE_INHIBIT

Use bounded inhibit only:

```text
multi_pulse_inhibit_count in {1, 2, 3}
inhibit_time_severe bounded
unlimited inhibit forbidden
```

Release requires:

```text
minimum_inhibit_time_elapsed == true
Vout <= Vref + reentry_band_down_severe
phase_order_valid == true
area_int_i within safe range
predicted_undershoot_penalty <= undershoot_budget_severe
```

Log:

```text
pulse_inhibit_count_actual
inhibit_start_time
inhibit_end_time
REQ_reject_reason
```

## AREA_HOLD

Prevent unsafe area-integrator accumulation during inhibit.

Design options:

```text
hold area_int_i
clamp area_int_i
bleed area_int_i toward safe preload
reset area_int_i at controlled reentry boundary
```

Log:

```text
area_hold_count
area_bleed_count
area_reset_count
area_int_max
area_int_at_reentry
```

## REENTRY_ARMED

Allow reentry only if:

```text
Vout <= Vref + reentry_band_down_severe
minimum_inhibit_time_elapsed == true
predicted_undershoot_penalty <= undershoot_budget_severe
phase_order_valid == true
current_limit_guard == pass
area_int_i within safe range
```

## CONTROLLED_REENTRY

Reintroduce pulses gradually:

```text
first accepted pulse must be phase-order valid
first accepted pulse must respect controlled_reentry_Ton_limit
burst_pulse_count_after_reentry <= burst_pulse_limit_after_reentry
REQ must not be silently dropped
```

Log:

```text
first_reentry_time_us
first_reentry_phase
first_reentry_Ton_ns
burst_pulse_count_after_reentry
```

## BALANCE_RECOVERY

After controlled reentry, enable only conservative recovery:

```text
allowed: C1low or C4a_conf
forbidden: C4c_cal, active Lambda, active-phase add/shed, aggressive Ton_diff
```

PIS-IEK may only be used here for current-sharing and event recovery. It must not be used to claim first-peak prediction.

## FALLBACK_SAFE

Fallback to A4/no-op style behavior if:

```text
predicted undershoot penalty exceeds budget
reentry burst risk is high
area_int_i is unsafe
phase order is invalid
current limit guard fails
logging required for interpretation is missing
```

Log:

```text
fallback_count
fallback_reason
```

Fallback prevents harm but is not evidence of A5 improvement by itself.
