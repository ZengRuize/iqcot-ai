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

## E040-A-R1 Confirmed Local Add-Insertion Model

E040-A-R1 produced a local `MODEL_CONFIRMED` result for the same moderate add case:

```text
experiment: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/
case: 20A -> 40A external load-current rise
transition: 2 -> 4 active phases
variants: R1-D0/R1-D1/R1-D2/R1-D3
classification: MODEL_CONFIRMED
```

The corrected model separates logical scheduler slots from physical phases:

```text
two-phase mode:
  active_phase_set = [1, 0, 1, 0]
  physical sequence = [1, 3]
  raw slots [1, 3] map to physical phase 1
  raw slots [2, 4] map to physical phase 3

four-phase mode:
  active_phase_set = [1, 1, 1, 1]
  physical sequence = [1, 2, 3, 4]
```

The add transition uses a controlled insertion schedule:

```text
ADD_PENDING:
  require load-rise branch, Iload > I_add_high, dwell pass, voltage guard, and current guard

NEW_PHASE_RAMP:
  insert phases 2 and 4 with bounded Ton

ORDER_RELOCK:
  hold a_S disabled while the four-phase event order relocks

BALANCE_RECOVERY:
  allow frozen guarded a_S only after ramp, relock, and reentry delay
```

Measured R1 local integrity:

```text
R1-D1/R1-D2/R1-D3:
  N_active_final = 4
  accepted_REQ_count = 145
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false

R1-D3:
  a_S_enable_time = 5.5 us
```

Voltage recovery remains a separate tuning axis. R1-D1 had the best local final voltage recovery among add variants, while R1-D2/R1-D3 demonstrated the guarded insertion and post-relock `a_S` timing at the cost of larger final error. Therefore R1 confirms local add-insertion integrity, not global active-phase benefit or shed behavior.

## E040-S0 Shed-Phase Revision Boundary

E040-S0 produced a `MODEL_REVISED` result for the first minimal shed attempt:

```text
experiment: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/
case: 40A -> 20A external load-current drop
transition target: 4 -> 2 active phases [1,3]
variants: S0/S1/S2/S3
classification: MODEL_REVISED
```

The evidence separates two failure modes:

```text
S1 immediate shed:
  N_active_final = 2
  peak undershoot = 663.614 mV
  final Vout error = -624.357 mV
  current_limit_hit = true

S2 dwell/lockout shed:
  N_active_final = 2
  peak undershoot = 543.833 mV
  final Vout error = -500.714 mV
  current_limit_hit = true
  phase_order_error_rate_post_shed = 0.265152

S3 residual/relock/a_S guarded shed:
  N_active_final = 3.79065
  peak undershoot = 19.133 mV
  final Vout error = -3.371 mV
  current_limit_hit = false
  phase_order_error_rate_post_shed = 0.992308
```

Thus, simply switching `active_phase_set` to `[1,0,1,0]` is not a valid shed model. A stable shed event must manage energy and event order before it removes phases:

```text
SHED_REQUEST
LOAD_SHARE_TRANSFER
DISABLED_PHASE_DRAIN
SHED_COMMIT
ORDER_RELOCK
BALANCE_RECOVERY
```

The revised shed model requires:

- retained phases must have current headroom before accepting load transfer;
- candidate shed phases must stop receiving new high-side energy while their residual current is drained under a bounded policy;
- residual-current thresholding must qualify the commit event, but it is not sufficient alone;
- post-shed two-phase order must be locked to the physical sequence `[1,3]`;
- frozen guarded `a_S` may act only after shed commit, order relock, voltage guard, and residual-current guard;
- active Lambda remains disabled.

E040-S0 does not validate phase shedding. It blocks S4/table-selected `a_N` shed claims until a staged shed-handoff model is built and locally confirmed.

## E040-S1 Confirmed Local Shed-Handoff Model

E040-S1 produced a local `MODEL_CONFIRMED` result for the same mild shed case:

```text
experiment: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/
case: 40A -> 20A external load-current drop
transition target: 4 -> 2 active phases [1,3]
variants: S1-R0/S1-R2/S1-R3
classification: MODEL_CONFIRMED
```

The confirmed local shed model adds two mechanisms missing from E040-S0:

```text
per-phase zero-current drain:
  phase_gate_enable_i = 0 only after abs(IL_i) <= residual_current_threshold

commit holding:
  active_phase_set remains [1,0,1,0] after the commit boundary
  unless a hard fallback guard trips
```

The `phase_gate_enable_i` mask is generated by the deterministic active-phase event manager after residual qualification. It prevents a disabled synchronous phase from pulling negative current through the low-side path after its inductor current reaches the residual band. It is not an AI gate command.

Measured S1-R3 local integrity:

```text
N_active_final = 2
actual_active_phase_set_final = 1010
shed_commit_count = 1
fallback_4ph_count = 0
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_shed = 0
current_limit_hit = false
residual_current_check = pass
peak undershoot = 0.641487 mV
final Vout error = 1.65264 mV
```

This validates only one local ideal-derived Simulink shed-handoff point. It does not validate S1-R4, severe shed cases, current-sense/DCR mismatch with active-phase scheduling, active Lambda, efficiency gain, or hardware/HIL/silicon behavior.
