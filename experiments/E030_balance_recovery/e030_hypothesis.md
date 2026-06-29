# E030 Balance-Recovery Hypothesis

Date: 2026-06-29

## Baseline

All E030 validation derives from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` is never modified directly. Derived copies must be created through MATLAB/Simulink APIs and saved under:

```text
models/derived/E030_<variant>_<short_purpose>_from_ideal_iqcot_<YYYYMMDD>.slx
```

## Purpose

E030 converts PIS-IEK actuator-classification evidence into a first closed-loop controller validation:

```text
Ton_diff    -> dominant DC current-sharing actuator
Lambda_diff -> phase-spacing / ripple-cancellation actuator
delay_diff  -> phase-jitter disturbance
```

The first chunk is intentionally narrow. It tests whether a PIS-IEK-guided projected balancer improves phase-current sharing under one DCR mismatch pattern while respecting phase-spacing, ripple, frequency, and trim guards.

## Mismatch and Operating Point

```text
load: 40 A constant external current sink
active phases: fixed four-phase
DCR nominal: 0.01 ohm
DCR pattern:
  phase 1: +10% -> 0.011 ohm
  phase 2: -10% -> 0.009 ohm
  phase 3: +10% -> 0.011 ohm
  phase 4: -10% -> 0.009 ohm
```

The DCR mismatch is a plant perturbation, not an AI action.

## Controller Variants

```text
C0 original ideal IQCOT with DCR mismatch
C1 Ton_diff only
C2 Lambda_diff only
C3 Ton_diff + Lambda_diff
C4 PIS-IEK projected balancer
```

No neural AI training is included in this experiment. C4 is a rule-based model projection.

## Control Hypotheses

### C1 Ton_diff Only

Use:

```text
I_avg = mean(IL_i)
e_I_i = IL_i - I_avg
Delta_Ton_i = clamp(-K_T * e_I_i, -T_trim_max, T_trim_max)
Delta_Ton_i = Delta_Ton_i - mean(Delta_Ton_i)
```

Expected effect: reduce DC current imbalance. Risk: phase spacing, ripple, or effective frequency can worsen if trims are too aggressive.

### C2 Lambda_diff Only

Use phase event-spacing error:

```text
e_phi_i = measured_phase_spacing_i - nominal_spacing
Delta_Lambda_i = clamp(-K_Lambda * e_phi_i, -Lambda_trim_max, Lambda_trim_max)
Delta_Lambda_i = Delta_Lambda_i - mean(Delta_Lambda_i)
```

In the first derived implementation, `Lambda_diff` is implemented as a bounded side-band event-spacing projection/logging proxy. It observes per-phase trigger timing and logs projected `Lambda_trim_i`, clamp, and fallback state, but it does not sit in series with the COT-cell trigger path. This boundary was introduced after an implementation check showed that sampling narrow REQ pulses inside a MATLAB Function block can drop events and invalidate the voltage loop. `Lambda_diff` should not be treated as a strong DC current-sharing actuator in this chunk.

### C3 Ton_diff + Lambda_diff

Combine C1 and C2:

```text
Ton_diff for current sharing
Lambda_diff for phase-spacing recovery
```

Both trims must remain zero-mean and bounded.

### C4 PIS-IEK Projected Balancer

The first C4 projection is rule based:

```text
if current imbalance is large and phase-spacing/ripple guards are acceptable:
    allow Ton_diff correction

if phase-spacing error is large:
    reduce Ton_diff aggressiveness and allow Lambda_diff correction

if trim, ripple, frequency, or phase-spacing guards are violated:
    clamp trims

if model confidence is low:
    fallback to baseline-safe behavior
```

## Metrics

```text
max current imbalance
RMS current imbalance
phase-spacing std
output ripple
effective switching frequency
Ton trim usage
Lambda trim usage
settling time of current imbalance
final Vout error
guard clamp count
fallback count

IL1_mean, IL2_mean, IL3_mean, IL4_mean
IL1_rms, IL2_rms, IL3_rms, IL4_rms
phase trigger times
phase order error rate
```

## Classification Rule

```text
MODEL_CONFIRMED:
  C4 improves current imbalance versus C0/C1/C2 while keeping phase-spacing std,
  ripple, frequency, and final error within budget.

MODEL_REVISED:
  Ton_diff improves current sharing but phase spacing/ripple cost requires a
  revised projection; or Lambda_diff helps phase spacing but does not improve
  current sharing; or C3/C4 only works under a narrower trim limit.

IMPLEMENTATION_ISSUE:
  DCR mismatch injection, trim path, logging, phase measurement, or derived
  model wiring is unreliable.

CLAIM_DOWNGRADED:
  PIS-IEK projected balancer does not improve current sharing or consistently
  worsens phase spacing/ripple.
```

## Non-Claims

- This first chunk does not prove general mismatch robustness.
- It is derived-Simulink evidence only, not hardware/HIL/board/silicon evidence.
- It does not validate neural AI control.
- It does not validate active-phase add/shed.
