# Safety-Projected AI/Table Supervision for Event-Domain IQCOT Voltage Regulation in Multiphase Buck VRMs

Draft date: 2026-06-30

## Abstract

This draft studies an AI/table-supervised parameter scheduling layer for a four-phase interleaved Buck voltage regulator using an ideal digital IQCOT baseline. The proposed architecture keeps the IQCOT loop as the fast deterministic event and pulse generator; the supervisor does not command gate signals and does not command the external load-current slew. Instead, it observes load-step direction and magnitude and proposes low-dimensional action tokens that are projected through model-based safety constraints before they modify IQCOT parameters or active-phase event states. Derived Simulink validation now covers bidirectional large-signal regulation, sensing-aware PIS-IEK current-sharing guards, and first local active-phase add/shed integrity points. For load drop, a magnitude-selected `a_O` token preserves no-op behavior for a mild `40A -> 20A` disturbance and selects Ton truncation plus one early event-domain pulse inhibit for a medium `40A -> 10A` disturbance, reducing the `2-12 us` recovery overshoot peak from `2.36936 mV` to `1.84342 mV` with a bounded `0.863951 mV` undershoot penalty. For load rise, a projected `a_U` token reduces peak undershoot in a severe `40A -> 120A` disturbance from `397.42 mV` to `319.08 mV` and reduces the 90% current-rise time from `37.996 us` to `1.212 us` without hitting the tested current guard. For current sharing, `Ton_diff` is confirmed as the dominant local DC balance actuator under a +/-10% DCR mismatch, while E030-R3 shows that confidence-gated or ideal-calibrated `a_S` projection can avoid real-current harm under one current-sense gain mismatch. For active phases, E040-A-R1 confirms one local `2 -> 4` insertion/relock integrity point, E040-S0 rejects simple immediate or dwell-only shed, and E040-S1 confirms one staged `4 -> [1,3]` shed handoff with exact `N_active_final = 2`, zero dropped/inactive accepted requests, zero post-shed order error, and residual-current qualification. These results support a limited claim of safety-projected supervisory scheduling in an ideal Simulink setting. They do not prove hardware, HIL, full 120A settling, broad mismatch robustness, broad active-phase robustness, efficiency improvement, or global optimality.

## 1. Introduction

Multiphase VRMs must regulate tightly under large load steps while maintaining phase-current balance, predictable interleaving, and safe active-phase transitions. Constant-on-time and IQCOT-style event controllers are attractive because they provide fast pulse decisions and natural pulse skipping. However, a single deterministic parameter set can be conservative across the full disturbance space: mild load drops may not need protection, medium drops may benefit from temporarily reducing high-side energy injection, and aggressive protection can create undershoot or reentry artifacts.

The research direction in this repository is:

```text
bidirectional large-signal voltage regulation
+ PIS-IEK small-signal current-sharing / phase-recovery model
+ active-phase add/shed hybrid event management
+ AI/table supervisor with safety projection
```

This draft reports the first completed validation loops for load-drop overshoot protection, load-rise peak-undershoot reduction, DCR-mismatch current-sharing recovery, current-sense-confidence protection, and local active-phase add/shed event integrity. Load current is always treated as an external disturbance. The AI/table layer may observe load-step direction, magnitude, and estimated slew, but it must not command the load-current profile.

## 2. Baseline and Control Boundary

All validation starts from the local ideal IQCOT baseline:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline is not modified directly. Every experiment builds a derived copy through MATLAB/Simulink APIs. The E001 audit classified the baseline as a four-phase synchronous Buck VRM with closed-loop IQCOT/COT event behavior:

```text
Vout/e_v -> Ideal_Digital_IQCOT_Request -> REQ_iqcot
REQ_iqcot -> global trigger chain -> PhaseScheduler_4Phase
PhaseScheduler_4Phase -> COT_Cell_1Phase1..4
COT cells -> GateDriver_1Phase1..4 -> QH/QL gates
IQCOT_Ton_Adapter -> Ton_iqcot1..4 -> COT cells
```

The AI/table supervisor therefore operates outside the fast gate path. It proposes event-domain and parameter-domain tokens, such as Ton truncation bounds or pulse-inhibit windows, and the safety projection decides whether these tokens are clamped, delayed, rejected, or applied.

## 3. Bidirectional Large-Signal Model

The large-signal model separates load-drop and load-rise hazards because the control direction is opposite. A load drop creates surplus inductor current and voltage overshoot risk. A load rise creates positive current deficit and voltage undershoot risk. Treating both as one scalar transient knob is unsafe because an action that removes high-side energy after a load drop can worsen a load-rise event.

### 3.1 Load-Drop Overshoot Branch

At a load drop, the inductor-current sum cannot change discontinuously:

```text
I_Lsum(t0+) = I_Lsum(t0-)
I_ex(t0+) = I_Lsum(t0+) - Iload_new
```

The output-capacitor voltage rise is dominated by surplus charge:

```text
Delta Vout ~= (1 / Cout) * integral(max(I_Lsum(t) - Iload_new, 0) dt)
```

A high-side pulse after the disturbance contributes approximately:

```text
Delta i_pulse ~= ((Vin - Vout) / L) * Ton_actual
```

Ton truncation can reduce residual injected current:

```text
Delta i_saved ~= ((Vin - Vout) / L) * max(Ton_nom - Tton_trunc_min, 0)
```

The revised model after E010 validation is:

```text
Delta Vout_peak =
  f(excess inductor current already stored at t0,
    residual high-side Ton energy,
    first accepted reentry trigger,
    safety-projected release condition)
```

This revision matters: Ton truncation alone is not a complete overshoot solution. It can reduce a recovery peak in one case but worsen undershoot in another. Pulse inhibit changes the first accepted reentry event and can provide the main improvement, but only when the projection prevents over-protection.

### 3.2 Load-Rise Undershoot Branch

At a load rise, the inductor-current sum also cannot change discontinuously:

```text
I_Lsum(t0+) = I_Lsum(t0-)
I_def(t0+) = Iload_new - I_Lsum(t0+)
```

The early droop is approximated by the positive deficit charge:

```text
Q_def(T) = integral_{t0}^{t0+T} max(Iload(t) - I_Lsum(t), 0) dt
Delta V_under(T) ~= Q_def(T) / Cout
```

One accepted high-side event changes the phase current approximately by:

```text
Delta i_i,on ~= ((Vin - Vout) / L_i) * Ton_actual_i
```

This gives two distinct `a_U` levers:

```text
fast request:
  increase accepted current-building event density

Ton boost:
  increase current increment per accepted event
```

E020 confirms the local ordering expected from this model: fast request dominates Ton boost alone in the severe `40A -> 120A` chunk, and the combination is strongest. The same E020 result does not prove complete settling; no B0-B3 variant returned within the `1 mV` band in the `90 us` post-step window.

## 4. Supervisory Action Token

The supervisor proposes:

```text
a_AI = [a_O, a_U, a_S, a_N]
```

The first validated branch is `a_O`, the load-drop overshoot token:

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

The safety projection is:

```text
a_projected = P_safe(a_AI, x_hat, mode, guards)
```

For E010, the current local selector is:

```text
DeltaI_drop = Iload_initial - Iload_final

if DeltaI_drop <= 20 A:
    project a_O to no-op or gentle protection
elif 20 A < DeltaI_drop <= 30 A:
    allow Ton truncation + one early pulse inhibit under undershoot budget
else:
    exclude severe 40A -> 1A improvement from the validated action set
```

These thresholds are evidence-local to the present ideal derived model. They are not universal controller constants. The severe branch is represented only as `a_O_severe_candidate`; A5 projected scheduling has been frozen as `MODEL_REVISED` boundary evidence, and any A6 structural energy-management mechanism is future work only.

The first load-rise branch is `a_U`:

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

The first E020 projection enables fast request and Ton boost only when:

```text
branch == load_rise
Vout <= Vref - undershoot_band
t is inside the boost/protection window
phase current guard passes
active-phase reentry lockout is false
```

In the first E020 chunk, the evidence-local projected parameters were:

```text
fast_request_window = 3 us
fast_request_period = 160 ns
fast_request_pulse_width = 25 ns
Tton_boost_max = 260 ns
boost_window = 3 us
current_limit_guard = 55 A/phase
```

The first balance-recovery branch is `a_S`:

```text
K_T
T_trim_max
K_Lambda
Lambda_trim_max
balance_recovery_rate
phase_spacing_weight
current_balance_weight
```

For E030, the tested Ton trim is zero-mean:

```text
I_avg = mean(IL_i)
e_I_i = IL_i - I_avg
Delta_Ton_i = clamp(-K_T * e_I_i, -T_trim_max, T_trim_max)
Delta_Ton_i = Delta_Ton_i - mean(Delta_Ton_i)
```

The first Lambda implementation was revised during validation. A sampled MATLAB Function inserted in series with the narrow REQ trigger path dropped events and invalidated the loop, so the retained E030 Lambda path is side-band projection/logging with fallback. This means E030 can discuss Lambda guard behavior but cannot yet claim an active event-native Lambda actuator.

E030-R2 showed why `a_S` cannot trust sensed-current imbalance blindly. With current-sense gains `[1.05, 0.95, 1.05, 0.95]`, aggressive Ton_diff reduced sensed imbalance but increased real phase-current imbalance. E030-R3 therefore freezes a local sensing-aware selector:

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

This selector supports the safety-projection architecture but remains local evidence. The calibrated modes assume ideal gain knowledge, `g_hat_i = g_i`, and do not prove practical online calibration.

The active-phase branch is `a_N`:

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

For add events, the projected `a_N` path must remap requests to the new active set, ramp inserted phases, relock the physical phase order, and delay any `a_S` recovery until voltage/reentry/order guards pass. For shed events, E040-S0 showed that residual threshold alone is not enough. The revised shed projection uses a staged hybrid handoff:

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

The executed E040-S1 implementation includes a deterministic `phase_gate_enable_i` safety mask after per-phase residual-current qualification. This mask is part of the model-based active-phase event manager; it is not an AI/table gate command.

## 5. Validation Method

The validation protocol follows these rules:

1. Audit the baseline wiring and required signals.
2. Create a derived model copy through MATLAB APIs.
3. Add only required observability or projected supervisory logic.
4. Run the smallest useful chunk first.
5. Generate CSV metrics and Markdown reports.
6. Classify the result as `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`.

The E010 load-drop metrics are:

```text
peak overshoot
early local peak 0-2us
recovery peak 2-12us
late settling 12-80us
undershoot penalty
reentry time
skip count
final error
```

The E020 load-rise metrics are:

```text
peak undershoot
current rise time
recovery overshoot
phase current peak
current limit hit
settling time
final error
event count during first 2us
Ton boost usage
fast-request count
```

The E030 current-sharing metrics are:

```text
max current imbalance
RMS current imbalance
phase spacing std
output ripple
effective switching frequency
Ton trim usage
Lambda trim usage
final voltage error
guard clamp count
fallback count
phase order error rate
```

The E040 active-phase metrics add event-integrity and hybrid-state checks:

```text
active phase timeline
N_active_final
actual_active_phase_set_final
add/shed commit count
fallback count
dropped_REQ_count
inactive_phase_REQ_count
phase_order_error_rate_post_add_or_shed
residual_current_check for shed
current_limit_hit
new phase ramp or disabled phase drain timing
post-transition a_S enable timing
peak overshoot/undershoot
final voltage error
```

## 6. Experimental Results

### 6.1 Medium Load Drop: 40A to 10A

The complete A0-A4 comparison is available in:

```text
experiments/E010_load_drop_overshoot/e010_a0_a4_40A_to_10A_comparison.md
```

| Variant | Description | Recovery peak 2-12us (mV) | Undershoot penalty (mV) | Interpretation |
|---|---|---:|---:|---|
| A0 | original ideal IQCOT | 2.36936 | 0 | baseline |
| A1 | Ton truncation only | 2.14559 | 0 | partial improvement |
| A2 | Ton truncation + one pulse inhibit | 1.84342 | 0.863951 | best recovery with bounded undershoot |
| A3 | guarded reentry, stricter band | 2.14559 | 0 | projection rejects pulse inhibit |
| A4 | table-selected `a_O` | 1.84342 | 0.863951 | selected A2-like action |

For this medium drop, A4 reduces the recovery peak by about `22.2%` versus A0 under a `1 mV` undershoot budget.

### 6.2 Mild Load Drop: 40A to 20A

| Variant | Recovery peak 2-12us (mV) | Undershoot penalty (mV) | Interpretation |
|---|---:|---:|---|
| A0 | 1.09036 | 0.45125 | baseline |
| A1 | 1.11391 | 3.58972 | Ton truncation too aggressive |
| A2 | -3.49921 | 8.51044 | pulse inhibit over-protects |
| A3 | 1.11391 | 3.58972 | pulse inhibit rejected, Ton truncation still too strong |
| A4 | 1.09036 | 0.45125 | table selects no-op |

This case demonstrates why the AI/table supervisor must be a selector rather than a fixed protection block.

### 6.3 Severe Load Drop: 40A to 1A

| Variant | Recovery peak 2-12us (mV) | Undershoot penalty (mV) | Interpretation |
|---|---:|---:|---|
| A0 | 3.61172 | 0 | baseline |
| A4 | 3.61172 | 0 | no-harm but non-improving |

The severe-drop result has now been extended through the A5 severe-token path:

```text
A5-C0/A5-C4 baseline audit: MODEL_CONFIRMED
A5-T1/T2/T3/T4 candidate comparison: MODEL_REVISED
A5-T4-R1 controlled reentry / burst limiter: MODEL_REVISED
A5-R2 reentry energy shaping / scheduler release: MODEL_REVISED
A5-R3 event-queue energy allocation: MODEL_REVISED
```

The frozen A5 evidence shows a repeated tradeoff. T3/T4 give a small recovery-peak reduction but fail the burst guard. R2-E1/E2 reduce recovery peaks more strongly but violate undershoot and burst guards. R1 and R3 variants suppress positive peaks only by starving recovery energy, producing about `971.618 mV` peak undershoot and `-919.625 mV` final error. Therefore A5 is used as negative / revision boundary evidence, not as a severe-drop improvement claim.

The manuscript distinction is:

```text
medium load drop:
  A4 provides useful local projected protection for the tested 40A -> 10A case

severe load drop:
  A5 projected scheduling has not passed the tested 40A -> 1A guard set
```

A structurally different A6 large-signal energy-management mechanism, such as an energy clamp or controlled recirculation mode, is future work only and is not part of the validated action set.

### 6.4 High-Load Boundary: 120A to 10A

The `120A -> 10A` A0 run produced a high-load operating-boundary issue in the current derived setup, including a very large undershoot-like metric before the load-drop behavior can be interpreted. This is classified as operating-boundary evidence and is excluded from improvement claims until the 120A baseline operating point is re-audited.

### 6.5 Severe Load Rise: 40A to 120A

The E020 B0-B3 comparison is available in:

```text
experiments/E020_load_rise_undershoot/e020_research_summary.md
```

| Variant | Description | Peak undershoot (mV) | 90% current-rise time (us) | Phase current peak (A/phase) | Interpretation |
|---|---|---:|---:|---:|---|
| B0 | original ideal IQCOT | 397.42 | 37.996 | 34.04 | baseline severe-rise response |
| B1 | fast request only | 343.79 | 2.658 | 33.90 | dominant first improvement |
| B2 | Ton boost only | 382.41 | 39.92 | 33.89 | weak alone because event count is unchanged |
| B3 | fast request + Ton boost | 319.08 | 1.212 | 34.09 | strongest first chunk result |

B3 reduces peak undershoot by `78.34 mV` relative to B0 and accelerates the 90% current-rise metric by about `31.3x`. The tested current guard is not hit.

This is a limited confirmation. B3 still has about `-297.93 mV` final error over the `75-90 us` post-step window, and no tested variant settles within the `1 mV` band in the simulated window. The result supports peak-undershoot and current-rise improvement, not complete 120A recovery.

### 6.6 DCR-Mismatch Current Sharing: Fixed 40A

The E030 C0-C4 comparison is available in:

```text
experiments/E030_balance_recovery/e030_research_summary.md
```

The first chunk uses fixed four-phase operation, a constant external `40A` load, and alternating DCR mismatch:

```text
DCR_L1/L3 = +10%
DCR_L2/L4 = -10%
```

| Variant | Description | Max imbalance (A) | Ripple (mV) | Ton usage | Final Vout error (mV) | Interpretation |
|---|---|---:|---:|---:|---:|---|
| C0 | original IQCOT with DCR mismatch | 0.853665 | 1.3133 | 0 | -2.277 | baseline mismatch imbalance |
| C1 | Ton_diff only | 0.313775 | 15.217 | 0.865969 | -58.156 | strongest balance, high voltage/ripple cost |
| C2 | Lambda_diff side-band only | 0.853665 | 1.3133 | 0 | -2.277 | no DC sharing improvement |
| C3 | Ton_diff + Lambda side-band | 0.313775 | 15.217 | 0.865969 | -58.156 | matches Ton_diff behavior |
| C4 | PIS-IEK projected balancer | 0.376221 | 16.075 | 0.53786 | -23.494 | balance improvement with lower Ton usage and smaller final error |

This is classified as `MODEL_REVISED`. It supports `Ton_diff` as the dominant DC current-sharing actuator in the tested local mismatch case. It does not support a claim that the first C4 projection is globally optimal or that `Lambda_diff` alone is a DC sharing actuator.

### 6.7 Current-Sense Gain Mismatch and Guarded a_S: E030-R3

E030-R2 introduced a sensing failure mode: under current-sense gain mismatch, the controller-observed sensed-current objective can diverge from real phase-current balance. E030-R3 tests the local guard rule using fixed four-phase operation, nominal power-stage DCR, and current-sense gains:

```text
[1.05, 0.95, 1.05, 0.95]
```

The comparison is available in:

```text
experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
```

| Variant | Description | Real max imbalance (A) | Sensed max imbalance (A) | Interpretation |
|---|---|---:|---:|---|
| R3-C0 | no correction baseline | 0.036272 | 0.538006 | real balance is already good despite sensed error |
| R3-C1low | low-gain fallback | 0.030506 | 0.522300 | no real-current harm |
| R3-C4a_conf | low-confidence no-op guard | 0.036272 | 0.538006 | blocks unsafe sensed optimization |
| R3-C4a_cal | ideal calibrated voltage-safe mode | 0.020618 | 0.523013 | improves real balance under ideal calibration |
| R3-C4c_cal | ideal calibrated balance mode | 0.025784 | 0.527296 | stronger balance mode under guards |

All R3 variants preserve accepted-REQ integrity and zero phase-order error. This is classified as `MODEL_CONFIRMED` for one local sensing-aware guard pattern. It does not prove imperfect calibration robustness or broad current-sense robustness.

### 6.8 Active-Phase Add Integrity: E040-A and E040-A-R1

The first active-phase add attempt, E040-A, showed that request remapping can avoid dropped requests but still violate phase-order integrity and leave large voltage error. E040-A-R1 retuned the insertion and scheduler order for the fixed moderate rise case:

```text
20A -> 40A external load-current rise
2 active phases -> 4 active phases
active Lambda disabled
```

The R1 comparison is available in:

```text
experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
```

For R1-D1/R1-D2/R1-D3, the local integrity gates passed:

```text
N_active_final = 4
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_add = 0
current_limit_hit = false
```

R1-D3 also verified delayed post-relock `a_S` timing:

```text
a_S_enable_time = 5.5 us
Ton_trim_usage = 0.204702
```

This is classified as `MODEL_CONFIRMED` only for local corrected-remap/insertion/relock integrity. It does not claim active-phase voltage benefit, severe load-rise recovery, arbitrary 1/2/4 scheduling, or active Lambda control.

### 6.9 Negative Shed Evidence: E040-S0

E040-S0 tested the first minimal `4 -> 2` shed policies for a fixed mild load drop:

```text
40A -> 20A external load-current drop
target active phases [1,3]
active Lambda disabled
```

The comparison is available in:

```text
experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_research_summary.md
```

| Variant | N_active_final | Peak undershoot (mV) | Final Vout error (mV) | Current limit | Post-shed order error | Interpretation |
|---|---:|---:|---:|---|---:|---|
| S0 | 4 | 0.451 | 0.699 | false | n/a | fixed four-phase reference |
| S1 | 2 | 663.614 | -624.357 | true | n/a | immediate shed is unsafe |
| S2 | 2 | 543.833 | -500.714 | true | 0.265152 | dwell-only shed is unsafe |
| S3 | 3.79065 | 19.133 | -3.371 | false | 0.992308 | residual/relock guard avoids worst voltage failure but does not hold two phases |

This is classified as `MODEL_REVISED`. It is useful negative evidence: active-phase shed requires staged current handoff and atomic commit; a residual-current predicate alone is not a sufficient shed accept rule.

### 6.10 Staged Shed-Handoff Confirmation: E040-S1

E040-S1 implements the revised shed model from E040-S0. It uses the same fixed mild shed case:

```text
40A -> 20A external load-current drop
initial active phases = 4
target active phases = [1,3]
target active phase mask = 1010
nominal DCR and current-sense gains
active Lambda disabled
```

The executed evidence is available in:

```text
experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
```

| Variant | Purpose | N_active_final | Active set | Commit | Fallback | Dropped REQ | Inactive REQ | Residual | Interpretation |
|---|---|---:|---|---:|---:|---:|---:|---|---|
| S1-R0 | fixed four-phase reference | 4 | 1111 | 0 | 0 | 0 | 0 | fail | reference/logging check |
| S1-R2 | transfer/drain, no commit | 4 | 1111 | 0 | 0 | 0 | 0 | pass | transfer/drain interpretable |
| S1-R3 | transfer/drain + atomic commit + relock | 2 | 1010 | 1 | 0 | 0 | 0 | pass | local shed-handoff integrity pass |

The key S1-R3 metrics are:

```text
phase_order_error_rate_post_shed = 0
current_limit_hit = false
peak undershoot = 0.641487 mV
final Vout error = 1.65264 mV
```

This is classified as `MODEL_CONFIRMED` for one local ideal-derived Simulink shed-handoff integrity point. The confirmed mechanisms are staged load-share transfer away from phases `[2,4]`, disabled-phase current drain, per-phase zero-current gate-enable masking, atomic commit to `[1,0,1,0]`, exact post-commit `N_active == 2`, and relock to physical sequence `[1,3]`. S1-R4, severe shed cases, active Lambda, mismatch with active-phase scheduling, and broad active-phase grids remain unrun.

## 7. Discussion

The E010-E040 loops produced eight useful findings.

First, the load-drop branch is not controlled by a single monotonic protection knob. Mild drops may be harmed by truncation; medium drops benefit from a projected combination of Ton truncation and one early pulse inhibit; severe `40A -> 1A` remains unresolved under projected scheduling tokens. A5 is therefore boundary evidence for the current action space, while any A6 energy-management mechanism is future work.

Second, safety projection is not optional. A3 showed that the reentry guard can become a binding constraint and reject pulse inhibit. The projection changes behavior, not just documentation.

Third, the current evidence supports a supervisor/table interpretation more strongly than an unconstrained AI-controller interpretation. The AI/table layer should propose low-dimensional action tokens; the model projection determines whether those actions are safe enough to touch IQCOT parameters.

Fourth, the load-rise branch behaves differently from the load-drop branch. E020 shows that fast event request is the primary severe-rise lever, while Ton boost alone is weak unless accepted event density also increases. This supports a bidirectional action space rather than a single transient-control variable.

Fifth, E030 supports the PIS-IEK actuator split but revises the controller claim. `Ton_diff` is the primary DC sharing actuator under the tested DCR mismatch, while `Lambda_diff` should remain a guarded phase-spacing/ripple variable until an event-native implementation is validated. C4 shows the value of projection as a trade-off mechanism: it gives less balance correction than aggressive Ton_diff-only control but reduces trim usage and final voltage error.

Sixth, E030-R2/R3 show that sensed-current objectives need their own safety projection. A controller can improve sensed balance while harming real balance when current-sense gains are mismatched. The frozen local selector therefore treats sensing confidence and calibration state as first-class guard variables before enabling stronger `a_S` action.

Seventh, active-phase add is primarily a scheduler-integrity problem before it is an efficiency or voltage-benefit problem. E040-A-R1 confirms that a corrected remap plus insertion/relock sequence can make a local `2 -> 4` transition without dropped or inactive accepted requests, but it does not yet show voltage improvement.

Eighth, active-phase shed is harder than add. E040-S0 rejected immediate and dwell-only shed because they force unsafe two-phase operation. E040-S1 confirmed that the shed event must be staged: transfer load share, drain disabled phases, apply a residual-qualified gate-enable safety mask, commit atomically, and relock the two-phase order. This is a local hybrid-event integrity result, not a broad active-phase robustness result.

## 8. Limitations

This draft does not claim hardware validation, HIL validation, board-level behavior, or silicon behavior. The evidence is Simulink-only and uses an ideal derived baseline. The current validation is also incomplete for:

- load-rise `a_U` behavior beyond the first `40A -> 120A` peak-undershoot chunk;
- complete load-rise settling and 120A final regulation;
- severe `40A -> 1A` load-drop improvement under projected scheduling tokens;
- A6 structural large-signal energy-management mechanisms, which are concept-only and unvalidated;
- robust PIS-IEK current-sharing and phase-recovery across mismatch families beyond the tested DCR and current-sense-gain chunks;
- practical online calibration accuracy for the E030-R3 calibrated `a_S` modes;
- active-phase add/shed behavior beyond the local E040-A-R1 add point and E040-S1 shed point;
- S1-R4 post-shed conservative `a_S` recovery;
- severe shed cases such as `40A -> 1A` or `120A -> 10A`;
- arbitrary 1/2/4 active-phase scheduling grids;
- active Lambda control;
- switching-efficiency improvement from phase shedding;
- high-load `120A` operating-point validity in the present derived model setup.

## 9. Next Work

The next research steps are:

1. Freeze E010-A5 as `MODEL_REVISED` severe-drop boundary evidence and do not run A5-R4 projected scheduling tweaks without a new structural hypothesis.
2. Tune the E020 `a_U` window and decide whether the residual 120A error requires phase-add or operating-boundary re-audit.
3. Convert the frozen E030-R3 sensing-aware `a_S` selector into a compact paper figure and claim-evidence table.
4. Prepare a new smallest-useful protocol before running S1-R4 post-shed conservative `a_S`; do not run it as an automatic extension of S1-R3.
5. Prepare separate protocols for severe shed cases, mismatch with active-phase scheduling, and broad 1/2/4 active-phase grids.
6. Implement an event-native Lambda_diff path before claiming active phase-spacing control.
7. Keep A6 structural energy management as a future-work concept note until a new model and protocol exist.
8. Convert this Markdown draft into LaTeX with evidence tables for E010, E020, E030-R3, E040-A-R1, E040-S0, and E040-S1.

## 10. Current Claim

The current defensible claim is:

```text
In the local ideal IQCOT derived Simulink model, a safety-projected table
supervisor can schedule low-dimensional event-domain IQCOT parameter tokens
without commanding gates or external load slew. For load drop, the a_O selector
preserves baseline behavior for a mild 40A -> 20A step and reduces the 40A ->
10A recovery peak by about 22.2% with a bounded 0.863951 mV undershoot penalty.
The severe 40A -> 1A load-drop A5 path is frozen as MODEL_REVISED boundary
evidence and is not claimed as an improvement.
For load rise, the first a_U chunk reduces 40A -> 120A peak undershoot from
397.42 mV to 319.08 mV and accelerates the 90% current-rise metric from
37.996 us to 1.212 us without hitting the tested current guard. For the first
DCR-mismatch balance chunk, Ton_diff reduces max current imbalance from
0.853665 A to 0.313775 A, while the C4 projected balancer reaches 0.376221 A
with lower Ton usage and smaller final Vout error magnitude than Ton_diff-only
control. Under one current-sense gain mismatch, E030-R3 confirms that a
confidence-gated or ideal-calibrated a_S projection can prevent sensed-current
optimization from harming real current balance. For active phases, E040-A-R1
confirms one local 20A -> 40A, 2 -> 4 insertion/relock integrity point, while
E040-S1 confirms one local 40A -> 20A, 4 -> [1,3] staged shed handoff with
N_active_final = 2, active set 1010, shed_commit_count = 1, fallback_count = 0,
dropped_REQ_count = 0, inactive_phase_REQ_count = 0, post-shed order error = 0,
current_limit_hit = false, and residual_current_check = pass. The evidence is
derived-Simulink evidence and does not yet prove complete 120A recovery, robust
mismatch recovery, broad active-phase robustness, efficiency improvement,
active Lambda control, hardware behavior, or HIL behavior.
```

## References To Complete

The final paper should verify and add formal references for:

- constant-on-time and adaptive on-time control in multiphase VRMs;
- current-mode and event-based multiphase Buck control;
- learning-assisted or table-supervised power converter control;
- safety projection / shielded learning in control systems;
- active-phase management in VRM systems.
