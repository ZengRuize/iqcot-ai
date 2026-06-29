# E030-R2 Current-Sense Mismatch Hypothesis

Date: 2026-06-29

## Baseline

All R2 validation derives from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` is never modified directly. Each R2 model is a derived copy created through MATLAB/Simulink APIs and saved under:

```text
models/derived/E030_R2_<variant>_current_sense_from_ideal_iqcot_20260629.slx
```

## Purpose

E030-R1 found two useful local `a_S` candidates under DCR mismatch:

```text
R1-C4a: conservative reduced-KT projection
R1-C4c: stronger voltage-aware projection
```

E030-R2 tests whether that trade-off remains meaningful when the controller's phase-current measurements are biased.

## Fixed Operating Point

```text
load: fixed 40 A external current sink
active phases: fixed four-phase
power-stage DCR: nominal on all phases
current-sense gain:
  phase 1: +5% -> 1.05
  phase 2: -5% -> 0.95
  phase 3: +5% -> 1.05
  phase 4: -5% -> 0.95
```

The load and current-sense mismatch are validation inputs, not AI actions.

## Variants

```text
R2-C0  original IQCOT with sensed-current logging only
R2-C1  Ton_diff-only reference using biased IL_sense feedback
R2-C4a R1 reduced-KT conservative projection using biased IL_sense feedback
R2-C4c R1 voltage-aware stronger projection using biased IL_sense feedback
```

No R2 variant directly commands QH/QL gates. No R2 variant commands load-current slew. No R2 variant uses active Lambda actuation.

## Real vs Sensed Current

The model logs:

```text
real current:   IL1..IL4
sensed current: IL_sense_i = Gsense_i * IL_i
```

The controller uses `IL_sense_i`, while the evidence must distinguish real current imbalance from sensed current imbalance. If sensed balance improves while real balance worsens, the claim must be revised and a current-sense-confidence guard is required.

## Scores

Lower is better:

```text
score_real = 0.40 * real_current_imbalance / C0_real_current_imbalance
           + 0.20 * abs(final_Vout_error_mV) / 60
           + 0.15 * Vout_ripple_pp_mV / 16
           + 0.15 * Ton_trim_usage
           + 0.10 * phase_spacing_std_ns / 50

score_sensed = same score, but using sensed_current_imbalance
```

## Classification Rule

```text
MODEL_CONFIRMED:
  R2-C4a or R2-C4c shows a clear real-current Pareto advantage versus C1,
  with lower trim, smaller voltage/ripple cost, intact phase rhythm, and no REQ loss.

MODEL_REVISED:
  projected variants help only under selected weights, sensed and real scores diverge,
  or a current-sense-confidence / calibration-aware guard is needed.

IMPLEMENTATION_ISSUE:
  current-sense mismatch injection, real/sensed logging, trim path, REQ logging,
  or postprocess is unreliable.

CLAIM_DOWNGRADED:
  projected a_S consistently worsens real current sharing or voltage/ripple behavior.
```

## Non-Claims

- No broad mismatch robustness claim.
- No hardware, HIL, board-level, or silicon claim.
- No active Lambda closed-loop claim.
- No active-phase add/shed claim.
- No neural AI controller claim.
