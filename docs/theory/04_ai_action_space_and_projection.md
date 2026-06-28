# AI Action Space and Projection

## Action Definition

The AI/table supervisor proposes:

```text
a_AI = [a_O, a_U, a_S, a_N]
```

The proposal is not applied directly. It is first passed through a model-based safety projection:

```text
a_projected = P_safe(a_AI, x_hat, mode, guards)
```

Only `a_projected` may reach IQCOT parameter scheduling.

## a_O: Load-Drop Overshoot Protection Token

For load decrease, for example `40A -> 10A`:

```text
protect_level_down
active_HS_trunc_enable
Tton_trunc_min
Tton_trunc_window
pulse_inhibit_count
inhibit_time
skip_hold_band
integrator_hold_reset_policy
reentry_band_down
reentry_release_policy
```

Purpose: remove or reduce excess high-side energy injection and safely reenter IQCOT.

## a_U: Load-Rise Undershoot Recovery Token

For load increase, for example `40A -> 120A`:

```text
boost_level_up
fast_request_enable
Lambda_cm_reduce
min_off_override_level
Ton_boost_enable
Tton_boost_max
boost_window
boost_decay_rate
phase_add_fast_enable
integrator_preload_policy
current_limit_guard
```

Purpose: increase inductor current fast enough to reduce `Vout` undershoot while avoiding current limit, saturation, and post-recovery overshoot.

## a_S: Small-Signal Current-Sharing / Phase-Recovery Token

```text
K_T
T_trim_max
K_Lambda
Lambda_trim_max
balance_recovery_rate
phase_spacing_weight
current_balance_weight
```

Purpose: use `Ton_diff` mainly for DC current sharing and `Lambda_diff` mainly for phase-spacing / ripple-cancellation recovery.

## a_N: Active-Phase Add/Shed Token

```text
N_active_candidate
I_add_high
I_shed_low
dwell_time
new_phase_ramp_rate
shed_lockout_after_protect
residual_current_threshold
phase_insert_policy
```

Purpose: manage 1/2/4 active phases without destabilizing voltage protection, reentry, or current sharing.

## Safety Projection Requirements

The projection must enforce:

- no direct gate-command control;
- no load-current command;
- bounds on `Ton`, `Lambda`, pulse inhibit, boost window, and trims;
- current-limit and saturation guards;
- reentry lockout rules;
- active-phase dwell and residual-current rules;
- branch consistency between load-drop and load-rise behavior;
- disabled active-phase add/shed during protection/reentry, except load-rise add-phase protection.

Projection failures are implementation evidence. They should be logged as projected, clamped, delayed, rejected, or fallback-to-baseline.

## Load-Drop Projection Rule from E010

The first E010 validation chunk supports the following concrete projection for `a_O`:

```text
a_O_raw =
  [Tton_trunc_min,
   Tton_trunc_window,
   pulse_inhibit_count,
   inhibit_time,
   reentry_band_down,
   reentry_release_policy]

a_O_projected = P_O(a_O_raw, x_hat)
```

The projection must reject or clamp pulse inhibit unless:

```text
branch == load_drop
active_phase_reentry_lockout == false
Vout >= Vref + reentry_band_down
predicted_undershoot_penalty <= undershoot_budget
current_limit_guard == pass
```

For the first `40A -> 10A` chunk, the table-selected token used:

```text
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
pulse_inhibit_count_guard = 1
inhibit_time = 1.8 us
reentry_band_down = 1.0 mV
undershoot_budget = 1.0 mV
```

This selected A4 produced the same measured behavior as A2:

```text
recovery peak reduction vs A0: about 22.2%
undershoot penalty: 0.863951 mV
```

With a stricter `reentry_band_down = 1.2 mV`, A3 rejected pulse inhibit and returned to A1-like behavior with zero undershoot penalty. This is evidence that the projection is a binding constraint, not merely a documentation label.

## Load-Drop Magnitude Selector

Subsequent E010 chunks revised `a_O` again. The `40A -> 20A` case showed that fixed Ton truncation and pulse inhibit are too aggressive for mild load drops:

```text
40A -> 20A:
A0 recovery peak 2-12us = 1.09036 mV
A1 recovery peak 2-12us = 1.11391 mV, undershoot penalty = 3.58972 mV
A2 recovery peak 2-12us = -3.49921 mV, undershoot penalty = 8.51044 mV
A4 no-op recovery peak 2-12us = 1.09036 mV, undershoot penalty = 0.45125 mV
```

The current projected selector is therefore:

```text
DeltaI_drop = Iload_initial - Iload_final

if DeltaI_drop <= 20 A:
    project a_O to no-op or gentle protection
elif 20 A < DeltaI_drop <= 30 A:
    allow Ton truncation + one early pulse inhibit under undershoot budget
else:
    require a revised severe-drop token before claiming improvement
```

The numeric thresholds are evidence-local to the current ideal derived model and must not be presented as universal controller constants.
