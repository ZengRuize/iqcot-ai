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

## Immediate Order

Proceed in this order:

1. Freeze current E010 and E020 findings in theory and claim boundaries.
2. Freeze E030 findings in theory and claim boundaries.
3. Retune E030 `a_S`: reduce C1/C3 voltage/ripple cost, refine C4 projection, and replace side-band Lambda logging with an event-native implementation before claiming active Lambda control.
4. Add or design a severe-drop `a_O` token for `40A -> 1A`.
5. Tune the E020 `a_U` window only after recording that the first B0/B1/B2/B3 chunk does not prove full 120A settling.
6. After E030 projection tuning, run E040 active-phase add/shed validation.
7. Update manuscript direction after the retuned E030 evidence is known.

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

## Standing Guardrails

- AI does not control external load slew.
- AI does not command high-side or low-side gates.
- IQCOT remains the deterministic fast pulse/event generator.
- Baseline `.slx` is never modified directly.
- Derived models must be created through MATLAB/Simulink APIs.
- Every derived model must have a hypothesis, metrics CSV, Markdown report, and classification.
- Simulink-only evidence must not be described as hardware, HIL, board-level, or silicon validation.
