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

Current validated/revised split:

```text
a_O_medium:
  supported for local medium load-drop protection under the tested 40A -> 10A case.

a_O_severe_candidate:
  design/revision candidate only.
  It includes active-HS-aware Ton truncation, bounded pulse inhibit,
  area-integrator management, controlled reentry, and event-queue /
  energy-allocation concepts, but it remains MODEL_REVISED for 40A -> 1A.
```

The supervisor may propose severe-drop scheduling actions, but current local evidence shows that projected scheduling alone can either fail to improve, cause burst/reentry guard violations, or starve recovery energy. Therefore `a_O_severe_candidate` remains outside the validated action set.

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
shed_lockout_after_protect
residual_current_threshold

For add-phase:
active_phase_remap_policy
phase_insert_policy
new_phase_ramp_rate
order_relock_window
post_add_aS_enable_guard

For shed-phase:
load_share_transfer_rate
disabled_phase_drain_policy
zero_current_gate_mask
shed_commit_boundary_policy
atomic_active_set_commit
two_phase_order_relock_window
post_shed_aS_enable_guard
fallback_4ph_policy
```

Purpose: manage 1/2/4 active phases without destabilizing voltage protection, reentry, or current sharing. `a_N` is not merely a phase-count selector. It is a guarded hybrid event-transition token. The supervisor proposes `a_N`, but only the projected and state-machine-qualified `a_N` reaches IQCOT parameter scheduling. It never commands gates directly.

## Local Active-Phase Evidence After E040-A-R1 and E040-S1

The current active-phase evidence is frozen as local derived-Simulink evidence. Add-phase and shed-phase are not symmetric.

For `2 -> 4` add, the main issue was active-phase remap, phase insertion, and post-add order relock. E040-A failed first because it reached four active phases without preserving post-add phase order. E040-A-R1 then confirmed local add integrity for the moderate `20A -> 40A` external load-current rise:

```text
E040-A-R1:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false
```

For `4 -> 2` shed, the main issue was load-share handoff and disabled-phase current management. E040-S0 showed that immediate or dwell-only shed can force two active phases but causes severe voltage/current-limit failure. E040-S1 then confirmed that staged load-share transfer, disabled-phase drain, atomic commit, and two-phase relock are required for the local mild `40A -> 20A` shed handoff:

```text
E040-S1 S1-R3:
  N_active_final = 2
  actual_active_phase_set_final = 1010
  shed_commit_count = 1
  fallback_4ph_count = 0
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_shed = 0
  current_limit_hit = false
  residual_current_check = pass
```

Allowed paper claim: local add/shed integrity mechanisms in the derived ideal IQCOT Simulink model. Forbidden claims remain broad active-phase robustness, arbitrary 1/2/4 scheduling, active Lambda control, efficiency improvement, hardware/HIL/silicon behavior, or severe load-rise/drop active-phase performance.

## E040-A-R1 Active-Phase Projection Rule

E040-A-R1 confirms a local `a_N` add-phase projection for the moderate external
`20A -> 40A` load-rise case:

```text
experiment: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/
classification: MODEL_CONFIRMED
```

The validated local two-phase mapping is:

```text
before add:
  active physical phases = [1, 3]
  raw scheduler slots [1, 3] -> physical phase 1
  raw scheduler slots [2, 4] -> physical phase 3

after add/relock:
  active physical phases = [1, 2, 3, 4]
  raw scheduler slot i -> physical phase i
```

The projected add action is allowed only when:

```text
branch == load_rise
Iload_est > I_add_high
Vout <= Vref + severe_overshoot_band
current_limit_guard == pass
dwell_timer >= dwell_time
protection/reentry lockout == false
```

The R1 local parameter set was:

```text
I_add_high = 30 A
dwell_time = 1 us
new_phase_ramp_time = 2 us
new_phase_Ton_limit = 0.75 * Ton_nom
order_relock_window = 2 us
post_add_reentry_delay = 0.5 us
current_limit_guard = 55 A/phase
```

The `a_S` balance token may not act during insertion. In R1-D3 it was enabled only after:

```text
N_active == 4
new_phase_ramp_state == COMPLETE
order_relock_window_done == true
post_add_reentry_delay elapsed
```

Measured local integrity evidence:

```text
R1-D1/R1-D2/R1-D3:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false

R1-D3:
  a_S_enable_time = 5.5 us
```

This validates only the local add-phase insertion/relock projection. It does not validate shed-phase behavior, broad 1/2/4 scheduling, active Lambda, severe load-rise recovery, or hardware/HIL behavior.

## E040-S0 Shed-Phase Projection Revision

E040-S0 tested the first minimal shed-phase branch for a mild external load drop:

```text
experiment: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/
case: 40A -> 20A
transition target: 4 -> 2 active phases [1,3]
classification: MODEL_REVISED
```

The tested simple shed policies are not sufficient:

```text
S1 immediate shed:
  stable N_active_final = 2
  peak undershoot = 663.614 mV
  current_limit_hit = true

S2 dwell/lockout shed:
  stable N_active_final = 2
  peak undershoot = 543.833 mV
  current_limit_hit = true
  phase_order_error_rate_post_shed = 0.265152

S3 residual/relock/a_S guarded shed:
  current_limit_hit = false
  peak undershoot = 19.133 mV
  N_active_final = 3.79065
  phase_order_error_rate_post_shed = 0.992308
```

The revised `a_N` shed projection may no longer treat residual-current threshold as a single sufficient accept condition. The next shed model must separate at least four event states:

```text
SHED_REQUEST:
  detect load-drop branch and Iload_est < I_shed_low

LOAD_SHARE_TRANSFER:
  increase/request-transfer support on retained phases [1,3]
  keep voltage and current-limit guards active

DISABLED_PHASE_DRAIN:
  inhibit new high-side energy on candidate shed phases [2,4]
  allow residual IL2/IL4 to decay under a bounded drain/freewheel policy

SHED_COMMIT_AND_RELOCK:
  commit active_phase_set = [1,0,1,0]
  relock scheduler order to [1,3]
  enable a_S only after commit, relock, voltage guard, and residual guard
```

Projection rule update:

```text
allow_shed_commit only if:
  branch == load_drop
  protection/reentry lockout == false
  retained_phase_current_headroom == pass
  disabled_phase_residual_current <= residual_current_threshold
  voltage deviation <= shed_voltage_budget
  order_relock_window can complete without dropped/inactive REQ
```

If these conditions are not met, the projection must delay shed or fall back to fixed four-phase operation. It must not oscillate between four-phase and two-phase states as a response to the instantaneous residual-current predicate.

## E040-S1 Confirmed Staged Shed-Handoff Projection

E040-S1 locally confirmed the staged `a_N` shed projection for one fixed mild load-drop case:

```text
experiment folder: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/
case: 40A -> 20A external load-current drop
transition: 4 -> [1,3]
variants: S1-R0/S1-R2/S1-R3
classification: MODEL_CONFIRMED
```

The revised shed `a_N` projection is a staged hybrid event:

```text
NORMAL_4PH
SHED_REQUESTED
LOAD_SHARE_TRANSFER
DISABLED_PHASE_DRAIN
SHED_COMMIT_ARMED
SHED_COMMIT
ORDER_RELOCK_2PH
POST_SHED_RECOVERY
NORMAL_2PH
FALLBACK_4PH
```

Projection variables added for the future implementation:

```text
shed_transfer_rate
shed_transfer_window
max_transfer_Ton_trim
remaining_phase_current_limit_guard
disabled_phase_drain_timeout
residual_current_threshold
shed_commit_boundary_policy
post_commit_order_relock_window
post_shed_aS_delay
shed_fallback_enable
shed_fallback_reason
```

Discrete observability required:

```text
shed_state
shed_transfer_progress
disabled_phase_current_sum
commit_armed
commit_done
fallback_4ph_triggered
fallback_reason
phase_gate_enable1..4
```

The confirmed projection adds a deterministic per-phase gate-enable safety mask after residual-current qualification:

```text
if phase i is a candidate shed phase
and shed_transfer_progress >= 0.5
and abs(IL_i) <= residual_current_threshold:
    phase_gate_enable_i = 0
```

This mask is part of the active-phase event manager and prevents disabled synchronous phases from becoming reverse-current sinks. It is not an AI/table gate command.

The commit rule is stricter than E040-S0:

```text
before commit:
  active_phase_set = [1,1,1,1]

after commit:
  active_phase_set = [1,0,1,0]
  N_active = 2 exactly
  accepted physical phases in [1,3] only
```

Post-shed `a_S` is conservative:

```text
allowed: C1low or C4a_conf
blocked: C4c_cal, active Lambda, aggressive Ton_diff
```

`a_S` may enable only after:

```text
commit_done == true
N_active == 2
phase_order_error_rate_window == 0
inactive_phase_REQ_count_window == 0
residual_current_check == pass
Vout within recovery band
post_shed_aS_delay elapsed
```

Measured S1-R3 local result:

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
```

This confirms only the local ideal-derived Simulink handoff mechanism. `S1-R4` remains unrun, active Lambda remains disabled, and no broad active-phase robustness or efficiency claim is allowed.

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
- current-sense confidence / calibration guard before applying current-sharing trims that depend on `IL_sense_i`.

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

## E010-A5 Severe-Drop a_O Boundary

The unresolved severe load-drop case is:

```text
40A -> 1A external load-current drop
active phases: fixed four-phase
power-stage DCR: nominal
current-sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
```

The current A4 selector is no-harm but non-improving for this case. A5 tested severe-drop projected scheduling through T/R1/R2/R3 revisions. The severe token is therefore frozen as a design/revision candidate, not validated evidence:

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
  burst_count_window_us,
  reentry_min_inter_pulse_spacing_us,
  first_reentry_Ton_limit_ns,
  recovery_Ton_ramp_rate,
  reentry_Ton_budget_ns,
  reentry_energy_budget_window_us,
  area_int_soft_preload_policy,
  scheduler_release_policy,
  voltage_window_release_policy,
  pending_REQ_queue,
  queue_max_depth,
  queue_release_min_spacing_us,
  queue_release_max_per_window,
  per_event_Ton_allocation_policy,
  queue_reject_policy,
  area_int_queue_coupling_policy,
  area_int_reentry_clamp,
  late_settling_guard,
  undershoot_budget_severe,
  fallback_to_A4_or_noop_guard
]
```

The intended mechanisms are:

```text
1. active-HS-aware Ton truncation;
2. bounded multi-event pulse inhibit;
3. area-integrator hold / controlled reset;
4. stricter but undershoot-budgeted reentry;
5. fallback-to-safe no-op/A4 if predicted undershoot penalty is too high.
```

A5 must not use the PIS-IEK small-signal model to predict the severe-drop first peak. The first peak is a large-signal excess-current / excess-energy behavior. PIS-IEK may only act after protection and reentry as conservative balance recovery.

The proposed observable A5 state machine is:

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

Initial candidate threshold:

```text
DeltaI_drop >= 30 A
```

This threshold is evidence-local to the current ideal derived model and must not be described as a universal controller constant.

### E010-A5-T4-R1 Projection Revision

A5-T4-R1 tested whether explicit burst-limited controlled reentry could turn the T4 proxy into a guard-passing severe-drop token:

```text
experiment: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/
classification: MODEL_REVISED
```

The tested R1 projection added:

```text
burst_count_window_us = 2
burst_pulse_limit_after_reentry = 2
reentry_min_inter_pulse_spacing_us = 0.4
first_reentry_Ton_limit_ns = 200
area_int_reentry_clamp = variant dependent
recovery_Ton_ramp = variant dependent
```

Measured result:

```text
R1-T4proxy:
  recovery peak 2-12us = 3.55696 mV
  peak undershoot = 0.697797 mV
  burst count / limit = 5 / 2

R1-T4a/b/c:
  peak overshoot = 0 mV
  recovery peak 2-12us = 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  REQ reject count = 170
  burst count / limit = 5 / 2
  guard_pass = false
```

Projection rule update:

```text
Do not accept positive-peak suppression as improvement when it is produced by
severe undershoot, final-error collapse, or a failed burst guard.
```

For severe load-drop, `P_O` must project the reentry token against both positive and negative energy budgets:

```text
P_O must satisfy:
  recovery_peak_budget
  undershoot_budget
  final_error_budget
  burst_pulse_limit
  event-spacing guard
  bounded area-integrator state
  scheduler release consistency
```

If these budgets cannot be satisfied together, the projection must fall back to the previous safe no-op/A4 boundary rather than applying a count-only burst limiter. The next A5 revision should shape reentry energy at the scheduler-release level and not only inhibit pulses after accepted reentry events have already clustered.

### E010-A5-R2 Reentry Energy-Shaping Revision

E010-A5-R2 tested the fixed severe `40A -> 1A` external load-current drop with fixed four phases, nominal DCR/sense, active Lambda disabled, and active-phase add/shed disabled:

```text
experiment: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/
classification: MODEL_REVISED
```

R2 adds these projected token dimensions to the severe-drop `a_O` design space:

```text
reentry_energy_budget_window_us
reentry_Ton_budget_ns
first_reentry_Ton_limit_ns
second_reentry_Ton_limit_ns
Ton_ramp_step_ns
Ton_ramp_max_ns
area_int_soft_preload_enable
area_int_preload_target
area_int_restore_rate
scheduler_release_fraction_initial
scheduler_release_ramp_rate
scheduler_release_window_us
voltage_window_release_enable
upper_reentry_band_mV
undershoot_budget_severe_mV
```

The R2 evidence keeps `a_O_severe` revised:

```text
R2-E1/E2:
  positive recovery peaks improve
  peak undershoot = 7.63188 mV
  burst count / limit = 5 / 2

R2-E3/E4:
  positive peaks collapse to 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  REQ reject count = 170
```

Projection rule update:

```text
Do not project scheduler release as a hard final-REQ gate or scalar pulse-count limiter.
The release policy must allocate accepted-event energy while preserving recovery energy.
If signed energy, burst density, undershoot, and final-error guards cannot all pass,
fallback to no-harm A4/no-op for this severe-drop boundary.
```

E2 shows that a logged soft preload is insufficient unless it actually modifies the area-integrator path. E4 shows that simply enabling a voltage-window flag does not fix a starvation-prone scheduler-release insertion point. A5-R2 therefore remains evidence for theory revision, not a validated severe-drop AI/table token.

### E010-A5-R3 Event-Queue Projection Revision

E010-A5-R3 tested whether the severe-drop token should move from scalar gating into explicit event-queue / per-event Ton allocation:

```text
experiment: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/
classification: MODEL_REVISED
```

The tested projected dimensions were:

```text
pending_REQ_queue
queue_depth
queue_phase_id
queue_age_us
queue_release_count
queue_reject_count
Ton_requested_ns
Ton_allocated_ns
Ton_budget_remaining_ns
reentry_Ton_budget_used_ns
area_int_queue_coupling_state
event_queue_state
energy_allocation_state
```

R3-E1/E2/E3 all failed the safety projection:

```text
peak undershoot = 971.618 mV
final Vout error = -919.625 mV
burst count / limit = 5 / 2
phase_order_error_rate = 1
guard_pass = false
```

Projection rule update:

```text
Do not accept event-queue/Ton allocation if positive recovery peaks disappear
because recovery energy is starved. The projection must reject or fallback when
signed energy, undershoot, final-error, burst, and phase-order guards cannot pass
together.
```

R3 does not validate `a_O_severe_candidate`. It only confirms that queue observability and per-event accounting are necessary but not sufficient.

### Frozen a_O Severe Boundary

After A5-R3, the `a_O` action-set boundary is:

```text
validated local tokens:
  a_O medium load-drop protection under tested medium drop
  a_U local peak-undershoot / current-rise acceleration under tested load-rise
  a_S calibration-aware guard under tested current-sense mismatch
  a_N local add/shed integrity under tested mild active-phase transitions

not validated:
  a_O severe 40A -> 1A improvement
  active Lambda
  broad active-phase scheduling
  broad mismatch robustness
```

Future severe-drop work should either stay outside the validated action set as an A6 structural energy-management concept, or return only with a new structural hypothesis. It must not tune R3 into a pass by broad sweeps.

## Load-Rise Projection Rule from E020

The first E020 validation chunk supports a local projection rule for `a_U`:

```text
a_U_raw =
  [fast_request_enable,
   Lambda_cm_reduce,
   min_off_override_level,
   Ton_boost_enable,
   Tton_boost_max,
   boost_window,
   boost_decay_rate,
   current_limit_guard]

a_U_projected = P_U(a_U_raw, x_hat)
```

The projection may enable fast scheduler requests only when:

```text
branch == load_rise
Vout <= Vref - undershoot_band
t in [t_load_step, t_load_step + fast_request_window]
max_i |IL_i| <= current_limit_guard
active_phase_reentry_lockout == false
```

For the first `40A -> 120A` E020 chunk, the evidence-local parameters were:

```text
fast_request_window = 3 us
fast_request_period = 160 ns
fast_request_pulse_width = 25 ns
undershoot_band = 0.2 mV
current_limit_guard = 55 A/phase
```

The projection may enable Ton boost only when:

```text
branch == load_rise
Vout <= Vref - undershoot_band
t in [t_load_step, t_load_step + boost_window]
Ton_cmd_i <= Tton_boost_max
|IL_i| <= current_limit_guard
```

For the first E020 chunk:

```text
Tton_boost_max = 260 ns
boost_window = 3 us
boost_decay_rate = 5e5 1/s
```

Measured local evidence:

```text
B0 peak undershoot = 397.42 mV
B1 fast request only = 343.79 mV
B2 Ton boost only = 382.41 mV
B3 fast request + Ton boost = 319.08 mV
```

The current `a_U` selector should therefore prefer fast request as the primary severe load-rise action and add Ton boost only under the same current and recovery guards. Ton boost alone should not be described as a complete load-rise recovery mechanism.

This evidence is local to the derived ideal model. The same E020 run did not settle within the `90 us` post-step window, so `a_U` is currently confirmed only for peak-undershoot reduction and current-rise acceleration, not for complete 120A recovery.

## E020-R1 Window-Tuned a_U Projection

E020-R1 refines the local `a_U` token without changing the fixed validation case:

```text
experiment: experiments/E020_load_rise_undershoot/R1_aU_window_tuning/
case: 40A -> 120A external load-current rise
active phases: fixed four-phase
active Lambda: disabled
active-phase add/shed: disabled
classification: MODEL_CONFIRMED
```

The R1 token under projection is:

```text
a_U_R1 = [
  fast_req_enable,
  fast_req_window_us,
  fast_req_threshold_mV,
  Ton_boost_enable,
  Ton_boost_gain,
  Ton_boost_window_us,
  Ton_boost_decay_policy,
  current_rise_target,
  current_limit_guard,
  late_recovery_guard,
  fallback_to_B0_guard
]
```

The confirmed local candidate is:

```text
R1-U1:
  fast_req_enable = true
  fast_req_window = 3 us
  fast_req_period = 160 ns
  fast_req_pulse_width = 25 ns
  Ton_boost_enable = true
  Ton_boost_window = 1.5 us
  Ton_boost_gain label = 1.0
  Tton_boost_max = 260 ns
  Ton_boost_decay_policy = short_window_B3_exponential
  current_limit_guard = 55 A/phase
  late_recovery_guard = disabled
```

R1-U1 evidence:

```text
peak undershoot = 318.801 mV
90% current-rise time = 1.196 us
final Vout error = -297.766 mV
REQ/accepted/dropped = 199/199/0
phase_order_error_rate = 0
current_limit_hit = false
```

The projection rule is:

```text
if branch == load_rise
and Vout <= Vref - undershoot_band
and t in fast_req_window
and max_i |IL_i| <= current_limit_guard:
    allow fast projected request pulses
else:
    fallback to nominal request path

if branch == load_rise
and Vout <= Vref - undershoot_band
and t in Ton_boost_window
and |IL_i| <= current_limit_guard
and Ton_cmd_i < Tton_boost_max:
    allow bounded Ton boost
else:
    fallback to nominal Ton
```

R1-U2, R1-U3, and R1-U4 did not carry forward:

```text
R1-U2 lower gain:
  peak undershoot = 325.954 mV
  final Vout error = -303.170 mV

R1-U3 stronger decay:
  peak undershoot = 346.678 mV
  90% current-rise time = 45.018 us
  final Vout error = -328.811 mV

R1-U4 late-recovery guard:
  peak undershoot = 344.252 mV
  90% current-rise time = 1.466 us
  final Vout error = -323.979 mV
  late_recovery_guard_trigger_count = 78
```

Claim boundary: R1-U1 confirms only a narrow window-tuned local `a_U` refinement. It does not prove full `120A` recovery, 1 mV settling, active Lambda, active-phase add, or broad load-rise robustness.

## Balance-Recovery Projection Rule from E030

The first E030 validation chunk supports a revised local projection rule for `a_S`:

```text
a_S_raw =
  [K_T,
   T_trim_max,
   K_Lambda,
   Lambda_trim_max,
   balance_recovery_rate,
   phase_spacing_weight,
   current_balance_weight]

a_S_projected = P_S(a_S_raw, x_hat, guards)
```

For the fixed `40A` DCR-mismatch chunk, the dominant DC sharing action is `Ton_diff`:

```text
I_avg = mean(IL_i)
e_I_i = IL_i - I_avg
Delta_Ton_i = clamp(-K_T * e_I_i, -T_trim_max, T_trim_max)
Delta_Ton_i = Delta_Ton_i - mean(Delta_Ton_i)
```

Measured local evidence:

```text
C0 max imbalance = 0.853665 A
C1 Ton_diff-only max imbalance = 0.313775 A
C4 projected balancer max imbalance = 0.376221 A
```

The projection must also account for the observed trade-off:

```text
C1 Ton usage = 0.865969, final Vout error = -58.156 mV
C4 Ton usage = 0.53786, final Vout error = -23.494 mV
```

Thus, the current `a_S` projection is not simply "maximize current sharing." It should solve a constrained local trade-off:

```text
minimize current_imbalance
subject to:
  Ton trim bound
  final Vout error budget
  ripple budget
  phase-order guard
  event-native implementation guard
```

`Lambda_diff` remains a projected phase-spacing / ripple-recovery variable, but E030 does not yet validate it as an active serial trigger-path controller. The first attempted serial sampled implementation dropped narrow trigger pulses and was rejected as an implementation issue. The retained implementation is side-band projection/logging with fallback when the projected Lambda trim violates guard limits.

## E030-R1 Retuned a_S Projection

E030-R1 revises the current `a_S` selector using the same fixed `40A`, fixed four-phase, alternating `DCR +/-10%` local mismatch case.

The current projected Ton trim rule is:

```text
Delta_Ton_raw_i = -K_T * (IL_i - mean(IL_i))
Delta_Ton_limited_i = clamp(Delta_Ton_raw_i, -T_trim_max, T_trim_max)
Delta_Ton_zero_sum_i = Delta_Ton_limited_i - mean(Delta_Ton_limited_i)

if max_i |Delta_Ton_zero_sum_i| > T_trim_max:
    Delta_Ton_i =
        Delta_Ton_zero_sum_i * T_trim_max / max_i |Delta_Ton_zero_sum_i|
else:
    Delta_Ton_i = Delta_Ton_zero_sum_i
```

Voltage-aware projection may further scale:

```text
voltage_scale =
    clamp(1 - max(|Vout - Vref| - V_error_budget, 0)
              / (V_error_hard_limit - V_error_budget),
          min_scale, 1)

Delta_Ton_i = voltage_scale * Delta_Ton_i
```

Current evidence:

```text
R1-C1 Ton_diff reference:
  max imbalance = 0.313749 A
  Ton usage = 0.866649
  final Vout error = -58.188 mV
  ripple = 15.311 mV

R1-C4a reduced-KT projection:
  K_T = 2.2e-9
  max imbalance = 0.416996 A
  Ton usage = 0.404392
  final Vout error = -3.604 mV
  ripple = 8.128 mV

R1-C4c voltage-aware projection:
  K_T = 5e-9
  projection_mode = voltage-aware
  max imbalance = 0.319450 A
  Ton usage = 0.676533
  final Vout error = -29.407 mV
  ripple = 7.121 mV
```

Selector implication:

```text
if final-voltage-error budget dominates:
    prefer R1-C4a-like reduced-KT projection
elif current-sharing recovery dominates and voltage error remains inside guard:
    allow R1-C4c-like voltage-aware projection
else:
    fall back toward Ton_diff reference or no-op according to guard status
```

The E030-R1 classification remains `MODEL_REVISED`, not `MODEL_CONFIRMED`, because the Pareto score is weight-dependent, Lambda remains side-band/logging only, and only one DCR mismatch pattern has been tested.

## Current-Sense Projection Guard from E030-R2

E030-R2 tested the R1 `a_S` candidates under fixed `40A`, fixed four-phase operation, nominal DCR, and current-sense gain mismatch:

```text
G_sense = [1.05, 0.95, 1.05, 0.95]
experiment: experiments/E030_balance_recovery/R2_current_sense_mismatch/
classification: MODEL_REVISED
```

This run separates the plant objective from the controller-observed objective:

```text
I_real_i = IL_i
I_sense_i = G_sense_i * IL_i
e_I_real_i = I_real_i - mean(I_real_i)
e_I_sense_i = I_sense_i - mean(I_sense_i)
```

The tested controller trims used `e_I_sense_i`. The metrics showed that the sensed objective can improve while real phase-current sharing worsens:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C4a real max imbalance = 0.317534 A
R2-C4a sensed max imbalance = 0.195376 A
R2-C4a final Vout error = -7.459 mV

R2-C4c real max imbalance = 0.432627 A
R2-C4c sensed max imbalance = 0.126599 A
R2-C4c final Vout error = -29.616 mV
```

The `a_S` token definition remains low dimensional, but the projection must now take a calibration state or confidence scalar as a guard input:

```text
a_S_projected = P_S(a_S_raw, x_hat, guards, current_sense_confidence)

if current_sense_confidence < confidence_min:
    freeze Ton_diff or strongly downscale K_T
    prefer baseline / voltage-safe low-gain fallback
    block R1-C4a and R1-C4c claims as robust current-sharing modes
else:
    allow R1-C4a-like or R1-C4c-like projection according to voltage/ripple guards
```

This is not an AI action that controls load-current slew, and it does not command gates. It is a model-based safety projection check on whether sensed current imbalance is trustworthy enough to drive IQCOT parameter trims.

At the R2 boundary, E040 active-phase add/shed had to remain blocked until a calibration-aware or confidence-aware `a_S` revision was validated, because add/shed events would otherwise mix active-phase dynamics with an unresolved current-sensing error.

## Frozen Local Guarded a_S Selector After E030-R3

E030-R3 validated the first calibration-aware / confidence-gated `a_S` revision for one local current-sense mismatch pattern:

```text
experiment: experiments/E030_balance_recovery/R3_calibration_aware_guard/
G_sense = [1.05, 0.95, 1.05, 0.95]
classification: MODEL_CONFIRMED
```

The local selector is now frozen for the next validation step. It is not a learned controller and it is not a gate command. It is a model-based safety projection that decides which low-dimensional `a_S` Ton-difference mode may reach the IQCOT parameter path:

```text
if sense_confidence == LOW:
    use no-op or low-gain Ton_diff fallback
elif calibration_enable == true and voltage/ripple risk is high:
    use calibrated C4a
elif calibration_enable == true and current imbalance dominates:
    allow calibrated C4c under voltage/ripple guards
else:
    fallback
```

Mode interpretation for subsequent E040 work:

- `C4a_cal` is the preferred voltage-safe calibrated mode.
- `C4c_cal` is the stronger current-sharing calibrated mode and remains subject to voltage/ripple/event guards.
- `C1low` is the low-confidence fallback mode.
- `C4a_conf` is the no-harm confidence-gated mode when sensing confidence is low.
- Active `Lambda_diff` actuation remains disabled; Lambda may be logged or projected as a boundary variable only.

Local R3 evidence:

```text
R3-C0 real max imbalance = 0.036272 A
R3-C1low real max imbalance = 0.030506 A
R3-C4a_conf real max imbalance = 0.036272 A
R3-C4a_cal real max imbalance = 0.020618 A
R3-C4c_cal real max imbalance = 0.025784 A

real_no_harm threshold = 0.056272 A
dropped_REQ_count = 0 for all R3 variants
phase_order_error_rate = 0 for all R3 variants
```

The calibrated variants use the ideal boundary `g_hat_i = g_i`. This supports the projection architecture, not a claim that calibration is available or accurate in hardware.

The frozen selector can be used after an active-phase add/reentry event in E040-A, but R3 itself still provides no active-phase add/shed evidence and no active Lambda control evidence. It also does not prove broad current-sense robustness or imperfect calibration robustness.
