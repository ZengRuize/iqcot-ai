# Safety-Projected AI/Table Supervision for Event-Domain IQCOT Voltage Regulation in Multiphase Buck VRMs

Draft date: 2026-06-29

## Abstract

This draft studies an AI/table-supervised parameter scheduling layer for a four-phase interleaved Buck voltage regulator using an ideal digital IQCOT baseline. The proposed architecture keeps the IQCOT loop as the fast deterministic event and pulse generator; the supervisor does not command gate signals and does not command the external load-current slew. Instead, it observes load-step direction and magnitude and proposes low-dimensional action tokens that are projected through model-based safety constraints before they modify IQCOT parameters. Derived Simulink validation currently covers the load-drop overshoot branch and the first load-rise undershoot chunk. For load drop, a magnitude-selected `a_O` token preserves no-op behavior for a mild `40A -> 20A` disturbance and selects Ton truncation plus one early event-domain pulse inhibit for a medium `40A -> 10A` disturbance, reducing the `2-12 us` recovery overshoot peak from `2.36936 mV` to `1.84342 mV` with a bounded `0.863951 mV` undershoot penalty. For load rise, a projected `a_U` token reduces peak undershoot in a severe `40A -> 120A` disturbance from `397.42 mV` to `319.08 mV` and reduces the 90% current-rise time from `37.996 us` to `1.212 us` without hitting the tested current guard. These results support a limited claim of safety-projected supervisory scheduling in an ideal Simulink setting. They do not prove hardware, HIL, full 120A settling, or global optimality.

## 1. Introduction

Multiphase VRMs must regulate tightly under large load steps while maintaining phase-current balance, predictable interleaving, and safe active-phase transitions. Constant-on-time and IQCOT-style event controllers are attractive because they provide fast pulse decisions and natural pulse skipping. However, a single deterministic parameter set can be conservative across the full disturbance space: mild load drops may not need protection, medium drops may benefit from temporarily reducing high-side energy injection, and aggressive protection can create undershoot or reentry artifacts.

The research direction in this repository is:

```text
bidirectional large-signal voltage regulation
+ PIS-IEK small-signal current-sharing / phase-recovery model
+ active-phase add/shed hybrid event management
+ AI/table supervisor with safety projection
```

This draft reports the first completed validation loops for load-drop overshoot protection and load-rise peak-undershoot reduction. Load current is always treated as an external disturbance. The AI/table layer may observe load-step direction, magnitude, and estimated slew, but it must not command the load-current profile.

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
    require a revised severe-drop token before claiming improvement
```

These thresholds are evidence-local to the present ideal derived model. They are not universal controller constants.

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

The severe-drop result does not support a broad improvement claim. It motivates a new token level, likely involving longer skip hold, reentry shaping, or a state-aware pulse-inhibit window.

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

## 7. Discussion

The E010 and E020 loops produced four useful findings.

First, the load-drop branch is not controlled by a single monotonic protection knob. Mild drops may be harmed by truncation; medium drops benefit from a projected combination of Ton truncation and one early pulse inhibit; severe drops need a different token.

Second, safety projection is not optional. A3 showed that the reentry guard can become a binding constraint and reject pulse inhibit. The projection changes behavior, not just documentation.

Third, the current evidence supports a supervisor/table interpretation more strongly than an unconstrained AI-controller interpretation. The AI/table layer should propose low-dimensional action tokens; the model projection determines whether those actions are safe enough to touch IQCOT parameters.

Fourth, the load-rise branch behaves differently from the load-drop branch. E020 shows that fast event request is the primary severe-rise lever, while Ton boost alone is weak unless accepted event density also increases. This supports a bidirectional action space rather than a single transient-control variable.

## 8. Limitations

This draft does not claim hardware validation, HIL validation, board-level behavior, or silicon behavior. The evidence is Simulink-only and uses an ideal derived baseline. The current validation is also incomplete for:

- load-rise `a_U` behavior beyond the first `40A -> 120A` peak-undershoot chunk;
- complete load-rise settling and 120A final regulation;
- PIS-IEK current-sharing and phase-recovery controller mismatch cases (`a_S`);
- active-phase add/shed hybrid event management (`a_N`);
- high-load `120A` operating-point validity in the present derived model setup.

## 9. Next Work

The next research steps are:

1. Add a severe-drop `a_O` token for `40A -> 1A`, with explicit skip-hold and shaped reentry.
2. Tune the E020 `a_U` window and decide whether the residual 120A error requires phase-add or operating-boundary re-audit.
3. Implement E030 mismatch validation for PIS-IEK current sharing and phase recovery.
4. Implement E040 active-phase add/shed validation after voltage protection and reentry guards are stable.
5. Convert this Markdown draft into a LaTeX manuscript once E030 evidence exists.

## 10. Current Claim

The current defensible claim is:

```text
In the local ideal IQCOT derived Simulink model, a safety-projected table
supervisor can schedule low-dimensional event-domain IQCOT parameter tokens
without commanding gates or external load slew. For load drop, the a_O selector
preserves baseline behavior for a mild 40A -> 20A step and reduces the 40A ->
10A recovery peak by about 22.2% with a bounded 0.863951 mV undershoot penalty.
For load rise, the first a_U chunk reduces 40A -> 120A peak undershoot from
397.42 mV to 319.08 mV and accelerates the 90% current-rise metric from
37.996 us to 1.212 us without hitting the tested current guard. The evidence is
derived-Simulink evidence and does not yet prove complete 120A recovery,
mismatch robustness, active-phase robustness, hardware behavior, or HIL behavior.
```

## References To Complete

The final paper should verify and add formal references for:

- constant-on-time and adaptive on-time control in multiphase VRMs;
- current-mode and event-based multiphase Buck control;
- learning-assisted or table-supervised power converter control;
- safety projection / shielded learning in control systems;
- active-phase management in VRM systems.
