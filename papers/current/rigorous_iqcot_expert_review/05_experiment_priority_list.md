# Experiment Priority List

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

## Priority 1: E020 Settling Audit

Protocol outline:

```text
Run B0, B3, R1-U1 with longer stop times:
  0.8 ms
  1 ms
  2 ms
```

Log:

```text
Vout average
I_Lsum average
Iload actual
Ton_actual_i
event density
comparator / area-integrator state
fast_req_state
Ton_boost_state
fallback-to-nominal state
```

Classify:

```text
SETTLING_TIME_INSUFFICIENT
STEADY_STATE_BIAS
MODEL_OR_MEASUREMENT_ISSUE
CONTROL_LIMITATION
```

Do not start this simulation in the present task.

## Priority 2: E030 Imperfect Calibration Mini-Test

Use the E030-R3 current-sense gain mismatch case and add residual calibration error:

```text
1%
2%
5%
```

The pass condition is real-current no-harm or improvement with REQ and phase-order guards clean.

## Priority 3: E040 Add/Shed Minimal Cross-Check

Use one nearby add case and one nearby shed case. The goal is not broad scheduling, but whether the confirmed state-machine logic survives a small perturbation.

## Priority 4: A6 Structural Severe-Drop Concept Only

Keep A6 as future work until a new structural energy-management hypothesis is specified. Do not tune A5-R4.

## Priority 5: Nonideal Digital Implementation Study

Study ADC delay, quantization, comparator delay, digital sampling, dead-time, and nonideal event timing only after the current local evidence package is paper-ready.
