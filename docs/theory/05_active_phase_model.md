# Active-Phase Model

## Purpose

Active-phase management is a hybrid event function that selects 1, 2, or 4 active phases to trade transient capability, ripple, current sharing, and switching activity.

It is not a free-running optimization knob. It must be coordinated with large-signal voltage protection, PIS-IEK recovery, and per-phase residual current.

## Add/Shed State

The active-phase state includes:

```text
active_phase_set
N_active
candidate_phase
dwell_timer
new_phase_ramp_state
shed_lockout_timer
residual_current_estimate
phase_spacing_recovery_state
```

The active set changes only at legal event boundaries.

## Load-Rise Add-Phase Protection

During a load-rise branch, phase add may be used as protection when projected safe:

```text
phase_add_fast_enable = true
```

The added phase must ramp current with a bounded `new_phase_ramp_rate` and must enter the PIS-IEK spacing recovery path. Current limit and post-recovery overshoot guards remain active.

## Load-Drop and Reentry Lockout

During load-drop overshoot protection, active-phase add/shed is disabled unless a later projected state exits protection and reentry. Shedding a phase while residual current is high can create imbalance, spacing disruption, and a secondary voltage peak.

The default lockout rule:

```text
if protection_active or reentry_active:
    disable add/shed
except load-rise add-phase protection
```

## Token Interface

Active-phase management uses token `a_N`:

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

The safety projection may reject a candidate active set when dwell, residual current, current limit, voltage branch, or phase-spacing constraints are not satisfied.

## E040-A Revision Boundary

The first minimal E040-A add-phase run produced `MODEL_REVISED` evidence:

```text
experiment: experiments/E040_active_phase_add_shed/
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: D0/D1/D2/D3
classification: MODEL_REVISED
```

Implementation lessons:

- An active-phase supervisor placed in the narrow `REQ` path must be event-preserving. A sampled MATLAB Function in the serial `REQ` path can miss narrow trigger pulses and is an implementation issue.
- A two-phase active set cannot be modeled by simply dropping phase-3/phase-4 requests, because that halves the effective request opportunity. The two-phase proxy must remap the four-phase scheduler events onto the active phases or use an active-phase-aware scheduler.
- The successful E040-A proxy therefore used request remapping before add and direct four-phase routing after add; it still did not satisfy phase-order and voltage-recovery guards.

Measured local outcome:

```text
D1/D2/D3 reached N_active_final = 4
dropped_REQ_count = 0
current_limit_hit = false
phase_order_error_rate = 0.120482 to 0.170732
peak undershoot = 802.746 mV to 810.494 mV
```

This revises the active-phase model: `active_phase_set` transition is necessary but not sufficient. The next E040-A revision must explicitly co-design phase insertion, scheduler order, dwell/ramp timing, and post-add Ton recovery before any E040-S shed validation.
