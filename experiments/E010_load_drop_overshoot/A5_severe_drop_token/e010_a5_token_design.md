# E010-A5 Severe-Drop a_O Token Design

Date: 2026-06-30

Status: DESIGN_ONLY

## Token

```text
a_O_severe = [
  severe_drop_detect_enable,
  DeltaI_drop_threshold_high,
  active_HS_trunc_enable,
  Tton_trunc_min_severe,
  Tton_trunc_window_severe,
  multi_pulse_inhibit_count,
  inhibit_time_severe,
  inhibit_release_condition,
  area_integrator_hold_policy,
  area_integrator_bleed_policy,
  area_integrator_reset_policy,
  reentry_band_down_severe,
  controlled_reentry_Ton_limit,
  burst_pulse_limit_after_reentry,
  late_settling_guard,
  undershoot_budget_severe,
  fallback_to_A4_or_noop_guard
]
```

The supervisor may propose this token, but only the projected token may reach IQCOT parameter scheduling. The token does not command high-side or low-side gates directly.

## Large-Signal Rationale

At the instant of the severe load drop:

```text
I_Lsum(t0+) ~= I_Lsum(t0-)
I_excess(t0+) = I_Lsum(t0+) - Iload_after
```

For the fixed A5 target:

```text
Iload_before = 40A
Iload_after = 1A
I_excess ~= 39A
```

This excess inductor current charges the output capacitor and creates overshoot. A5 therefore targets additional high-side energy injection, unsafe early reentry events, and stored area-integrator state. PIS-IEK must not be used to predict the severe-drop first peak; it may only help after protection/reentry for current-sharing and event recovery.

## Severe-Drop Detection

```text
DeltaI_drop = Iload_before - Iload_after

if branch == load_drop
and DeltaI_drop >= DeltaI_drop_threshold_high:
    enter SEVERE_DROP_DETECTED
```

Initial local candidate:

```text
DeltaI_drop_threshold_high = 30A
```

This threshold is evidence-local and must not be claimed as universal.

## Mechanism 1: Active-HS-Aware Ton Truncation

Purpose: reduce residual high-side energy when a severe load drop occurs during or near an accepted high-side pulse.

Projected behavior:

```text
if branch == load_drop
and DeltaI_drop >= DeltaI_drop_threshold_high
and active_HS_trunc_enable == true:
    Ton_cmd_i = max(Tton_trunc_min_severe, projected_remaining_Ton_i)
```

This is projected Ton scheduling, not a direct gate command. If the derived model cannot reliably log active high-side pulse timing, classify the run as `IMPLEMENTATION_ISSUE`.

## Mechanism 2: Bounded Multi-Event Pulse Inhibit

Purpose: prevent unsafe immediate reentry pulses after a severe excess-current event.

Candidate bounds:

```text
multi_pulse_inhibit_count in {1, 2, 3}
inhibit_time_severe bounded by future protocol
inhibit_release_condition requires voltage, minimum-time, phase-order, and area-state guards
```

Unlimited inhibit is forbidden because it can create undershoot and reentry oscillation.

## Mechanism 3: Area-Integrator Hold / Controlled Reset

Purpose: prevent area-integrator state from accumulating into a burst reentry trigger.

Candidate policies:

```text
hold area_int_i
clamp area_int_i
reset area_int_i at reentry boundary
bleed area_int_i toward safe preload
```

Metrics must log:

```text
area_hold_count
area_reset_count
area_bleed_count
area_int_max
area_int_at_reentry
```

## Mechanism 4: Undershoot-Budgeted Reentry

Reentry may arm only when:

```text
Vout <= Vref + reentry_band_down_severe
predicted_undershoot_penalty <= undershoot_budget_severe
minimum_inhibit_time_elapsed
current_limit_guard == pass
phase_order_valid == true
```

Controlled reentry rules:

```text
first accepted pulse must be phase-order valid
do not accept burst pulses
limit first recovery Ton
monitor Vout undershoot
```

## Mechanism 5: Fallback Safe

If A5 predicts excessive undershoot or unstable reentry:

```text
fallback to A4/no-op style safe behavior
```

Fallback is not success by itself. It is a safety projection that prevents a harmful A5 action.

## State Machine

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

| State | Purpose | Exit |
|---|---|---|
| `NORMAL` | IQCOT operates normally | severe load drop detected |
| `SEVERE_DROP_DETECTED` | latch load-drop branch, DeltaI_drop, Vout, IL1..IL4, area_int_i | projection selects A5 or fallback |
| `ACTIVE_HS_TRUNCATE` | project severe Ton truncation for active or imminent HS pulse | truncation window expires |
| `PULSE_INHIBIT` | block bounded number of unsafe reentry events | inhibit count/time complete |
| `AREA_HOLD` | hold, clamp, reset, or bleed area integrator | reentry guard is satisfied |
| `REENTRY_ARMED` | wait for voltage, undershoot, current, and phase-order guards | controlled reentry allowed |
| `CONTROLLED_REENTRY` | allow first recovery pulses with Ton and burst guards | recovery stable |
| `BALANCE_RECOVERY` | allow conservative C1low or C4a_conf only | balance guard done |
| `FALLBACK_SAFE` | revert to A4/no-op style safety behavior | stable baseline behavior |

## Balance Recovery Boundary

Allowed after reentry:

```text
C1low
C4a_conf
```

Forbidden in A5 first validation:

```text
C4c_cal
active Lambda
active-phase add/shed
aggressive Ton_diff
```
