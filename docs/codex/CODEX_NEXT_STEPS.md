# Codex Next Steps

Date: 2026-06-29

## Current State

E010 load-drop overshoot validation has already produced a `MODEL_REVISED` result. Do not restart from the old first E010 task or from `A1 Ton truncation only`.

E020 load-rise undershoot validation has produced the first `MODEL_CONFIRMED` chunk for the local peak-undershoot/current-rise mechanism. Do not restart the first `40A -> 120A` B0/B1/B2/B3 run unless the model wiring or postprocess code changes.

Current E010 evidence:

```text
40A -> 20A:
  mild load drop; fixed Ton truncation / pulse inhibit is too aggressive.
  A4 projects to no-op or very gentle protection.

40A -> 10A:
  medium load drop; A4 selected Ton truncation + one early pulse inhibit.
  recovery peak improved by about 22.2% with 0.863951 mV undershoot penalty.

40A -> 1A:
  severe load drop; current A4 is no-harm but non-improving.
  severe-drop a_O token is still missing.

120A -> 10A:
  operating-boundary check only.
  do not use it as improvement evidence yet.
```

E030 balance-recovery validation has now produced a first `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
C0 max current imbalance = 0.853665 A
C1 Ton_diff-only max current imbalance = 0.313775 A
C2 Lambda_diff-only max current imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff max current imbalance = 0.313775 A
C4 projected balancer max current imbalance = 0.376221 A
classification: MODEL_REVISED
```

C4 improves current sharing versus C0 and uses less Ton trim than C1/C3, with smaller final Vout error magnitude, but it does not beat the Ton_diff-only current-imbalance metric.

E030-R1 projection retune has now produced a second `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: R1-C0, R1-C1, R1-C4a, R1-C4b, R1-C4c, R1-C4d
summary: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md
metrics: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv
classification: MODEL_REVISED
```

Best current `a_S` candidates:

```text
R1-C4a reduced-KT projection:
  max imbalance = 0.416996 A
  Ton usage = 0.404392
  final Vout error = -3.604 mV
  ripple = 8.128 mV
  Pareto score = 0.362552

R1-C4c voltage-aware projection:
  max imbalance = 0.319450 A
  Ton usage = 0.676533
  final Vout error = -29.407 mV
  ripple = 7.121 mV
  Pareto score = 0.415946
```

R1-C4a is the best scored trade-off candidate; R1-C4c is the stronger current-sharing candidate. No R1 variant validates active Lambda control.

E030-R2 current-sense mismatch confirmation has now produced a third `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R2-C0, R2-C1, R2-C4a, R2-C4c
summary: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md
metrics: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
classification: MODEL_REVISED
```

Key R2 result:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C4a real max imbalance = 0.317534 A
R2-C4a sensed max imbalance = 0.195376 A
R2-C4a Ton usage = 0.401338
R2-C4a final Vout error = -7.459 mV

R2-C4c real max imbalance = 0.432627 A
R2-C4c sensed max imbalance = 0.126599 A
R2-C4c Ton usage = 0.681135
R2-C4c final Vout error = -29.616 mV
```

R2 confirms that R1-C4a/R1-C4c are not robust under current-sense gain mismatch as-is. The sensed-current objective can improve while real phase-current balance worsens. Add a current-sense-confidence or calibration-aware guard before any E040 active-phase add/shed validation.

## Immediate Order

Proceed in this order:

1. Freeze current E010 and E020 findings in theory and claim boundaries.
2. Freeze E030 findings in theory and claim boundaries.
3. Treat R1-C4a/R1-C4c as local DCR-mismatch candidates, not robust fixed selectors.
4. Add and validate one calibration-aware or current-sense-confidence `a_S` revision under E030-R2 before E040.
5. Only after the sensing guard passes, freeze the local `a_S` mode selector for fixed four-phase balance recovery.
6. Add or design a severe-drop `a_O` token for `40A -> 1A`.
7. Tune the E020 `a_U` window only after recording that the first B0/B1/B2/B3 chunk does not prove full 120A settling.
8. Run E040 active-phase add/shed validation only after the guarded `a_S` projection rule is stable.
9. Update manuscript direction after the guarded E030 revision or downgrade decision.

## E020 First Chunk Result

Completed:

```text
Load step: 40A -> 120A
Compare: B0 original ideal IQCOT, B1 fast request only, B2 Ton boost only, B3 fast request + Ton boost
Classification: MODEL_CONFIRMED

B0 peak undershoot: 397.42 mV
B1 peak undershoot: 343.79 mV
B2 peak undershoot: 382.41 mV
B3 peak undershoot: 319.08 mV

B0 90% current-rise time: 37.996 us
B3 90% current-rise time: 1.212 us
```

Boundary: E020 confirms local peak-undershoot reduction and current-rise acceleration, not full recovery. B0-B3 did not settle within the 1 mV band in the 90 us post-step window.

Do not add phase-add until E020 window tuning and E030 balance evidence are reviewed.

## E030-R2 Confirmation Result

Completed:

```text
Load: fixed 40A
Active phases: fixed 4-phase
Power-stage mismatch: none
Current-sense mismatch: [1.05, 0.95, 1.05, 0.95]
Compare: R2-C0, R2-C1, R2-C4a, R2-C4c
Classification: MODEL_REVISED
```

Boundary: E030-R2 shows a real-vs-sensed current-sharing divergence. Ton_diff and projected `a_S` can reduce the controller-observed sensed imbalance while worsening real phase-current imbalance. R2-C4a reduces trim and voltage-error cost versus aggressive R2-C1, but it still worsens real imbalance versus R2-C0. R2-C4c improves sensed imbalance most, but it also worsens real imbalance. Do not start E040 from this state.

Next smallest useful experiment:

```text
E030-R3 calibration-aware a_S guard:
  keep fixed 40A and fixed four phases
  reuse the R2 current-sense gain pattern
  compare baseline, low-gain fallback, confidence-gated C4a, and calibrated C4a/C4c if calibration is explicitly modeled
  require real-current improvement or a no-harm real-current fallback before unblocking E040
```

## Standing Guardrails

- AI does not control external load slew.
- AI does not command high-side or low-side gates.
- IQCOT remains the deterministic fast pulse/event generator.
- Baseline `.slx` is never modified directly.
- Derived models must be created through MATLAB/Simulink APIs.
- Every derived model must have a hypothesis, metrics CSV, Markdown report, and classification.
- Simulink-only evidence must not be described as hardware, HIL, board-level, or silicon validation.
