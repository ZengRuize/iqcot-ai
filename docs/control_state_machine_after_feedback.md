# R048 Draft Control State Machine and Model-Wiring Plan

Date: 2026-06-24

This document translates the R046/R047 research direction into a concrete
controller state machine and derived-model wiring checklist. It is a design
document only: no `.slx` file is modified here.

## Control State Machine

```text
NORMAL_IQCOT
  -> CUT_LOAD_DETECT
  -> CUT_LOAD_PROTECT
  -> SKIP_HOLD
  -> REENTRY
  -> BALANCE_RECOVERY
  -> NORMAL_IQCOT

NORMAL_IQCOT
  -> PHASE_ADD_PENDING
  -> BALANCE_RECOVERY
  -> NORMAL_IQCOT

NORMAL_IQCOT
  -> PHASE_SHED_PENDING
  -> BALANCE_RECOVERY
  -> NORMAL_IQCOT
```

Phase shedding is disabled in:

- `CUT_LOAD_DETECT`
- `CUT_LOAD_PROTECT`
- `SKIP_HOLD`
- `REENTRY`
- `BALANCE_RECOVERY`

## State Definitions

| State | Entry condition | Main action | Exit condition |
|---|---|---|---|
| `NORMAL_IQCOT` | no protection or phase transition active | ordinary area-event IQCOT | cut-load, add-phase, or shed-phase condition |
| `CUT_LOAD_DETECT` | `dVout/dt > S_ov` or `I_excess > I_excess_th` | compute PR-ECB features | risk class available |
| `CUT_LOAD_PROTECT` | `r_p >= r_mid` or active-HS high-risk event | Ton truncation, pulse inhibit, integrator hold/reset | Vout begins to return or inhibit timer expires |
| `SKIP_HOLD` | protection action has inhibited new HS pulses | allow inductor current decay | `Vout < Vref + Vreentry_high` |
| `REENTRY` | Vout is back in reentry band | restore phase sequence and integrator policy | stable event sequence observed |
| `BALANCE_RECOVERY` | reentry complete or phase count changed | PIS-IEK `Ton_diff`/`Lambda_diff` recovery | current and phase errors inside limits |
| `PHASE_ADD_PENDING` | undervoltage/load-rise/add threshold | enable new active phase with ramp | new phase current is controllable |
| `PHASE_SHED_PENDING` | light load, dwell expired, balanced state | remove selected phase safely | disabled phase current decayed |

## Guard Conditions

### Cut-load detection

```text
cut_load_detected =
    dVout_dt > S_ov
 or Iload_drop_est > I_drop_th
 or sum(IL_i) - Iload_est > I_excess_th
```

### PR-ECB risk class

```text
r_p = DeltaV_bound / DeltaV_allow

low  : r_p < r_low
mid  : r_low <= r_p < r_high
high : r_p >= r_high or active_HS_large_drop
```

### Add phase

```text
request_add =
    Vout < Vref - Vuv_th
 or Iload_est > I_add_high(N_active)
```

Add-phase has higher priority than shed-phase.

### Shed phase

```text
request_shed =
    protect_state == NORMAL_IQCOT
 and Iload_est < I_shed_low(N_active)
 and abs(Vout - Vref) < V_shed_band
 and max(abs(IL_i - Iavg)) < I_balance_band
 and phase_spacing_std < phi_shed_band
 and dwell_timer > T_dwell
```

## Proposed Derived Signals

| Function | Existing signal/block to inspect | Proposed derived signal | Reason |
|---|---|---|---|
| Output voltage | `Vout` logging path in derived model | `Vout_log` | overshoot and reentry metric |
| Load estimate | load-current source or measured branch current | `Iload_est` | cut-load and add/shed decision |
| Phase currents | `IL1..IL4` | `IL_vec` | PR-ECB, current sharing, residual current |
| High-side states | gate outputs to HS MOSFETs | `HS_vec` | active-HS detection and Ton truncation |
| Low-side states | gate outputs to LS MOSFETs | `LS_vec` | dead-time and synchronous rectification audit |
| Area requests | `REQ1..REQ4` or scheduler request bus | `REQ_vec` | event sequence and skip count |
| Phase index | phase manager state | `phase_idx` | PIS-IEK event indexing |
| Active set | new phase manager state | `active_phase_set` | phase add/shed hybrid model |
| Actual Ton | gate pulse width measurement | `Ton_actual_i` | truncation and trim verification |
| Commanded Ton | existing constant or trim input | `Ton_cmd_i` | `Ton_diff` balance actuator |
| Area threshold | IQCOT threshold path | `Lambda_i` | `Lambda_diff` phase actuator |
| Integrators | area accumulator states | `area_int_i` | hold/reset and reentry verification |
| Protection state | new state machine output | `protect_state` | event classification |
| Skip state | request inhibited or skipped pulse | `skip_flag` | cut-load and reentry metrics |
| Reentry state | reentry manager output | `reentry_flag` | reentry timing |
| Phase spacing | trigger-time differences | `phase_spacing_i` | ripple-cancellation metric |

## Proposed Derived Blocks

| Block | Inputs | Outputs | Notes |
|---|---|---|---|
| `PR_ECB_Risk_Estimator` | `Vout`, `IL_vec`, `Iload_est`, `HS_vec`, `Cout`, `ESR`, `L`, `DeltaV_allow` | `r_p`, `bound_family`, `active_HS_class` | offline-calibrated rules from R043 first |
| `Cut_Load_Protector` | `r_p`, `Vout`, `dVout_dt`, `HS_vec`, state timers | `ton_truncate_i`, `pulse_inhibit_i`, `hold_int_i`, `reset_int_i` | hard guard; not AI-generated gate command |
| `Reentry_Manager` | `Vout`, `REQ_vec`, `phase_idx`, `skip_flag`, timers | `reentry_flag`, `phase_realign_cmd`, `int_recover_policy` | prevents arbitrary restart after skip |
| `PIS_IEK_Balancer` | `IL_vec`, `phase_spacing_i`, `active_phase_set` | `Ton_trim_i`, `Lambda_trim_i` | `Ton_diff` for DC sharing, `Lambda_diff` for phase spacing |
| `Phase_Add_Shed_Controller` | `Iload_est`, `Vout`, `e_I`, `e_phi`, `protect_state`, dwell timers | `active_phase_set_req`, `phase_ramp_cmd` | shedding disabled during protection/reentry |
| `AI_Action_Projector` | optional `a_AI`, model features, guard state | `a_safe` | future layer; can be replaced by rule table |

## Initial Parameter Placeholders

These are design placeholders, not final tuned values:

| Parameter | Meaning | Initial handling |
|---|---|---|
| `r_low` | low/mid PR-ECB risk boundary | choose conservatively after A0/A1 baseline |
| `r_high` | high-risk protection boundary | start below `1.0`, tune from derived cases |
| `N_inhibit_max` | maximum inhibited events | limit to avoid long undervoltage recovery |
| `T_trim_max` | `Ton_diff` trim limit | derive from PIS-IEK and pulse-width resolution |
| `Lambda_trim_max` | `Lambda_diff` trim limit | derive from phase-spacing tolerance |
| `I_add_high` | add-phase current threshold | hysteresis above shed threshold |
| `I_shed_low` | shed-phase current threshold | only active after dwell and balance checks |
| `T_dwell` | add/shed dwell time | much slower than cut-load protection |

## Required Inspection Before Model Build

Before building the derived copy, inspect:

1. whether MOSFET `Ron`, body diode, `Rd`, `Vfd`, `Rs`, and `Cs` are variables
   or hard-coded literals;
2. whether `L`, DCR, `Cout`, and ESR are variables or hard-coded literals;
3. where `Ton` is generated and whether it can be truncated safely;
4. whether each phase has an accessible area integrator state;
5. where `REQ` enters the phase scheduler;
6. whether skip/reentry behavior already exists or must be added;
7. solver and time-step settings for measuring `5 ns` to `15 ns` class effects.

Do not edit `.slx` XML directly. Use MATLAB APIs and save a derived model copy.

## Adaptive Revision Hooks

The state machine is allowed to change during validation, but only through
explicit revision hooks:

| Validation observation | State-machine revision hook |
|---|---|
| protection lowers first peak but causes secondary undershoot | adjust `SKIP_HOLD -> REENTRY` threshold and inhibit timer |
| reentry causes phase disorder | add stronger `phase_realign_cmd` in `REENTRY` |
| balance recovery is slow | adjust `BALANCE_RECOVERY` trim gains and limits |
| `Ton_diff` hurts phase spacing | add phase-cost guard before leaving `BALANCE_RECOVERY` |
| shed event causes overshoot | extend shed lockout after cut-load/reentry |
| add event causes current spike | add new-phase current ramp state or integrator reset |
| simple OV skip inhibits requests but does not reduce first peak | keep OV skip as `SKIP_HOLD` / request-inhibit only; require `CUT_LOAD_PROTECT` to include Ton truncation or active-HS remaining-on-time truncation for first-peak protection |
| OV-triggered Ton truncation fires after the active high-side pulse has ended | add a trigger-timing guard; distinguish pre-threshold/load-step-synchronous active-HS truncation from post-threshold skip-hold |

Every such revision must be logged in a refine-log and synchronized to the
claims/evidence matrix before further grid expansion.

## R049B State-Machine Revision

R049B validated a minimal simple OV-skip insertion on a new derived copy.  The
gate entered the request path as:

```text
Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip)
```

In the `40A -> 1A near0` two-offset chunk, this gate inhibited later requests
for about `19 us`, but did not reduce the first peak.  Therefore the state
machine should treat simple OV skip as a `SKIP_HOLD` action after over-voltage
is detected, not as the primary `CUT_LOAD_PROTECT` action for first-peak
suppression.

Revised priority:

```text
CUT_LOAD_PROTECT:
    active-HS / first-peak action first
        -> Ton truncation or remaining-on-time truncation
    then SKIP_HOLD:
        -> simple OV skip / pulse inhibit for reentry control
```

## R049C State-Machine Confirmation

R049C confirms the revised priority above for the tested near0 chunk.  A
command-path Ton-truncation action reduced the first peak only at the offset
with remaining active high-side on-time:

```text
0.05 us offset:
    remaining Ton4: about 52 ns -> about 2 ns
    first peak: 6.2586 mV -> 5.4926 mV

0.105 us offset:
    remaining Ton4: 0 ns
    first peak unchanged at 5.9603 mV
```

State-machine implication:

```text
CUT_LOAD_PROTECT should carry the Ton-truncation / active-HS action.
SKIP_HOLD should carry later request inhibit and reentry management.
```

The state machine should not claim that truncation helps every phase offset.
Its first confirmed control value is phase-state selective.

## R049E State-Machine Revision

R049E downgrades the broader Ton-truncation generalization for the mild
`40A -> 20A` hold-out.  At the `0.05 us` active-HS boundary, the A2 truncation
flag asserted only after about `0.228 us`, when `qh4=0`, and the first peak was
unchanged:

```text
0.05 us offset:
    first peak: 2.1103 mV -> 2.1103 mV
    remaining Ton4: about 52 ns -> about 52 ns
    trunc flag: about 0.518 us total, but too late for the active pulse

0.105 us offset:
    remaining Ton4: 0 ns
    first peak unchanged at 2.0936 mV
```

State-machine implication:

```text
CUT_LOAD_PROTECT:
    if active-HS risk is known early enough:
        use pre-threshold / load-step-synchronous Ton truncation diagnostic
    else if over-voltage is already detected after the active pulse:
        treat as post-threshold monitoring / skip-hold, not first-peak removal
```

The state machine should now carry both phase-state and trigger-timing guards
before claiming first-peak protection from Ton truncation.

## R049F State-Machine Revision

R049F confirms the trigger-timing diagnosis but rejects a global early action.
The early time-window variant removed the active phase-4 remaining on-time in
the `40A -> 20A`, `0.05 us` row:

```text
remaining Ton4: about 52 ns -> 0 ns
```

However, the same global all-phase early Ton-min action caused severe
undervoltage-like behavior in both offsets:

```text
0.05 us:  A2 peak metric -184.1030 mV, final error -239.1723 mV
0.105 us: A2 peak metric -189.3089 mV, final error -241.9473 mV
```

State-machine implication:

```text
CUT_LOAD_PROTECT:
    phase_selective_active_HS_truncation:
        allowed only for phases currently high-side active
        must be guarded by early risk / phase state
    global_all_phase_early_Ton_min:
        disallowed except as an unsafe diagnostic
```

The next state-machine validation should test `early_window AND qh_i` or an
equivalent active-HS-only guard.

## R049G State-Machine Revision

R049G repaired the early-window lower bound by explicitly connecting
`t_load_step` to `R049C_After_LoadStep/2`, then tested:

```text
ton_truncate_i = early_window AND Memory(qh_i)
```

At the `40A -> 20A`, `0.05 us` active-HS offset, this did truncate only the
active phase and reduced phase-4 remaining Ton:

```text
remaining Ton4: about 52 ns -> about 2 ns
```

However, the first-peak metric worsened:

```text
A0 peak: 2.1103 mV
A2 peak: 2.3879 mV
```

At `0.105 us`, where no phase had remaining active high-side Ton, A2 was
identical to A0.

State-machine implication:

```text
CUT_LOAD_PROTECT:
    hard_active_HS_Ton_min:
        not accepted as a safe/useful PR-ECB action for mild 20A cut-load
        until early local spike and recovery peak metrics are separated

    phase_state_guard:
        necessary but insufficient

    metric_guard:
        must check immediate local spike, recovery peak, and late undershoot
```

The next validation should be an offline R049H waveform-metric audit rather
than another blind action chunk or a full A matrix.

## R049H State-Machine Revision

R049H did not change the plant model or run new switching simulation.  It
audited existing R049C/R049D/R049E/R049F/R049G waveforms with three response
windows:

```text
EARLY_LOCAL_PEAK: 0-2 us
RECOVERY_PEAK:    2-12 us
LATE_SETTLING:    12-80 us
```

State-machine implication:

```text
CUT_LOAD_PROTECT acceptance gate:
    require no unacceptable increase in EARLY_LOCAL_PEAK
    require intended improvement in RECOVERY_PEAK or documented trade-off
    check LATE_SETTLING / undershoot before promoting the action

hard_active_HS_Ton_min:
    rejected as a confirmed mild-load action after R049G/R049H

gentle_phase_selective_Ton_trim:
    next candidate action, but only as a single R049I chunk
```

R049H decision:

```text
MODEL_REVISED
```

## R049I State-Machine Revision

R049I tested the next candidate action from R049H:

```text
gentle_phase_selective_Ton_trim:
    trigger = early_window AND Memory(qh_i)
    Tton_trunc_min = 120 ns
```

Before running the chunk, R049I audited the R049G baseline Ton trace.  At the
`40A -> 20A`, `0.05 us` active-HS offset:

```text
Ton_cmd4: 196.5 ns
remaining Ton4: about 52 ns
elapsed on-time before load step: about 144.5 ns
```

Because `Tton_trunc_min` feeds the COT cell as a whole-pulse Ton command, not a
remaining-on-time floor, the `120 ns` floor is already expired when the action
starts.  The R049I result matched that risk: remaining Ton4 fell to about
`2 ns`, but early local peak worsened by `0.2902 mV`.

State-machine implication:

```text
CUT_LOAD_PROTECT:
    Ton_floor_actions:
        do not continue scanning floors when elapsed_on_time > floor

    next_action_family:
        deferred_post_active_pulse_inhibit
        or controlled_reentry

    acceptance_gate:
        continue using EARLY_LOCAL_PEAK, RECOVERY_PEAK, and LATE_SETTLING
```

R049I decision:

```text
MODEL_REVISED
```

## R049J State-Machine Revision

R049J tested the next action family:

```text
post_active_inhibit:
    start after current active-HS pulse natural end
    inhibit future scheduler requests only
```

The inserted gate is request-path only:

```text
allow_to_scheduler = existing_allow AND NOT(post_active_inhibit)
```

At the `0.05 us` active-HS offset, the selected inhibit window starts at
`0.070 us`, after the baseline qh4 natural falling edge at about `0.052 us`.
This preserves current-pulse semantics:

```text
remaining Ton4: 52 ns -> 52 ns
Ton-trunc duration: 0 us
```

But hard inhibit still causes reentry stress:

```text
0.05 us recovery undershoot penalty: -2.9901 mV
0.105 us recovery undershoot penalty: -4.1571 mV
```

State-machine implication:

```text
CUT_LOAD_PROTECT:
    fixed_post_active_inhibit:
        not accepted as final PR-ECB action

    controlled_reentry:
        next candidate action
        restore requests softly after inhibit / recovery gate

    metric_guard:
        include recovery undershoot, not only positive peak
```

R049J decision:

```text
MODEL_REVISED
```

## R049K State-Machine Revision

R049K tested a shortened request-path soft-reentry proxy:

```text
soft_reentry = 0.070 us -> 1.760 us
```

The end point was selected from the first future request / qh1 boundary around
`1.678-1.690 us`.  This preserves the R049J no-current-pulse-truncation rule:

```text
remaining Ton4 at 0.05 us: 52 ns -> 52 ns
```

However, the three-window result still shows a fixed-window trade-off:

```text
recovery peak improvement: +0.1796 / +0.1954 mV
recovery undershoot penalty: -0.6388 / -1.6588 mV
late positive peak change: -0.1318 / -0.0223 mV
```

State-machine implication:

```text
CUT_LOAD_PROTECT -> REENTRY:
    fixed scalar post-active inhibit windows are not enough

    next candidate:
        edge-aligned one-shot request restoration
        or phase-aware release

    metric_guard:
        preserve EARLY_LOCAL_PEAK
        preserve RECOVERY_PEAK benefit
        explicitly penalize RECOVERY_UNDERSHOOT and LATE_PEAK
```

R049K decision:

```text
MODEL_REVISED
```

## R049L Repair State-Machine Revision

R049L repair tested the intended next family:

```text
phase_boundary_one_shot_reentry:
    inhibit_raw = 0.070 us -> 1.760 us
    release_trigger = qh1 rising edge during inhibit_raw
    allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

The A0 baseline was repaired and now matches R049K.  The state-machine issue is
in A2: `qh1` is downstream of `allow_to_scheduler`, so it cannot be the causal
release trigger while the gate is blocking requests.

```text
R049L repair A2:
    one_shot_edge_count = 0
    one_shot_time_us = NaN
    effective_inhibit_duration = full 1.690 us
```

R049L repair decision:

```text
IMPLEMENTATION_ISSUE
```

State-machine rule after R049L repair:

```text
controlled_reentry:
    release_trigger must be upstream of the request-path gate
    valid candidates:
        scheduler internal slot / phase-boundary signal
        independent phase clock
        explicitly exposed phase-index transition that continues during inhibit

    invalid as causal trigger:
        downstream qh_i gate output suppressed by allow_to_scheduler

    qh_i may still be logged as an effect / safety check
```

## R049M State-Machine Revision

R049M audited whether the existing scheduler exposes an upstream release clock.
It does not. The actual chain is:

```text
existing_allow
    -> R049L_Gate_And
    -> Allow
    -> Detect Rise Positive
    -> tr
    -> PhaseScheduler_4Phase trigger
    -> phase_state / phase_idx / phase_en
    -> per-phase triggers
    -> qh_i
```

This means the scheduler is event-driven by allowed requests, not by an
independent phase clock.

R049M decision:

```text
MODEL_REVISED
```

State-machine rule after R049M:

```text
controlled_reentry:
    release_trigger_class:
        independent_phase_clock
        or predicted_scheduler_slot

    calibration:
        first release event near R049K boundary 1.678-1.690 us

    forbidden release causes:
        req_global comparator edge
        existing_allow
        Allow/tr
        phase_state or phase_idx from current triggered scheduler
        phase_en/tr_i
        downstream qh_i
```

## R049N State-Machine Revision

R049N implemented the first upstream-causal reentry release:

```text
independent_clock_reentry:
    inhibit_raw = t_load_step + 0.070 us through 1.690 us duration
    release_clock = t_load_step + 1.685 us
    one_shot_done = first release_clock event during inhibit_raw
    allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

This passes the causal state-machine gate: `release_clock` is generated outside
the inhibited request/scheduler path and continues to evolve while requests are
blocked.  A2 one-shot times were `1.750 us` and `1.735 us` for the two offsets.

R049N decision:

```text
MODEL_REVISED
```

State-machine rule after R049N:

```text
controlled_reentry:
    use upstream-causal release signal
    verify release_clock and one_shot_done both fire
    keep current active-HS Ton untruncated
    evaluate early/recovery/late windows separately

    if recovery undershoot worsens:
        revise release timing or soft-reentry slope
        do not claim controller confirmation
```

## R049O Timing Bracket

R049O tested earlier binary releases using the same upstream-causal interface:

```text
release_clock = t_load_step + 1.250 us
release_clock = t_load_step + 1.450 us
```

Both one-shot releases fired, but the resulting waveforms were identical to A0
in the R049H windows.  State-machine interpretation:

```text
binary_release_timing:
    too_early <= 1.450 us:
        release is causal but transparent
    1.685 us:
        release has measurable recovery effect but creates undershoot penalty

next:
    test narrow intermediate timing
    or replace binary restore with soft/ramped restore
```

## R049P Midpoint Result

R049P tested:

```text
release_clock = t_load_step + 1.600 us
```

The state machine fired correctly, but behavior was offset-selective:

```text
0.050 us: transparent, no windowed delta
0.105 us: active, recovery peak improves but recovery undershoot remains
```

State-machine implication: a single global binary release delay is unlikely to
be sufficient unless paired with phase/offset awareness or softened restoration.

## R049Q Later-Point Result

R049Q tested:

```text
release_clock = t_load_step + 1.630 us
```

The state machine fired correctly:

```text
0.050 us: one_shot_done = 1.670 us
0.105 us: one_shot_done = 1.695 us
```

But the behavior moved toward the hard-release penalty:

```text
0.050 us: still transparent
0.105 us: recovery peak improves slightly more than R049P
          recovery undershoot worsens substantially versus R049P
```

State-machine implication: binary release delay is a sharp timing knob.  Moving
later than `1.600 us` strengthens the reentry action but reintroduces the
undershoot failure mode.  Next control-state revision should use either a
between-point (`1.610-1.620 us`) or a soft/ramped restore token.
