# E030-R3 Calibration-Aware a_S Guard Hypothesis

Date: 2026-06-29

## Objective

E030-R3 tests whether a current-sense-confidence or calibration-aware `a_S` guard can prevent Ton-difference current-sharing control from optimizing biased sensed current while harming real phase-current balance.

## Baseline Rule

All derived models are copied from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline model is not modified. All edits are applied to derived `.slx` copies through MATLAB/Simulink APIs.

## Fixed Validation Condition

R3 reuses the E030-R2 condition:

```text
external load: fixed 40 A
active phases: fixed four-phase
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
active Lambda actuation: disabled
```

The load current and current-sense mismatch are validation inputs, not AI-controlled actions.

## Current-Sense Model

```text
IL_sense_i = g_i * IL_real_i
IL_est_i = IL_sense_i / g_hat_i
```

For calibrated variants, the first R3 chunk uses the ideal boundary case:

```text
g_hat_i = g_i
```

This does not claim practical calibration accuracy. It only tests whether the R2 failure mode is caused by biased current information.

## Variants

```text
R3-C0:
  baseline with current-sense mismatch and no a_S correction

R3-C1low:
  low-gain Ton_diff fallback under low sensing confidence

R3-C4a_conf:
  R1-C4a proposal blocked by confidence guard and forced to fallback

R3-C4a_cal:
  R1-C4a projection using ideal calibrated current estimate IL_est_i

R3-C4c_cal:
  R1-C4c voltage-aware projection using ideal calibrated current estimate IL_est_i
```

## Guard Logic

The implemented first-pass guard is:

```text
if calibration_enable == false and current_sense_mismatch_flag == true:
    sense_confidence = LOW
    use fallback_K_T
else if calibration_enable == true:
    use IL_est_i = IL_sense_i / g_hat_i
```

The real-current no-harm condition is:

```text
real_no_harm = real_max_imbalance_variant <= real_max_imbalance_C0 + 0.02 A
```

## Expected Outcomes

`MODEL_CONFIRMED` is possible only if at least one guarded or calibrated variant satisfies real-current no-harm or real-current improvement, with no dropped REQ events and no phase-order error.

If calibrated variants still improve sensed current while worsening real current, R3 remains `MODEL_REVISED` or becomes `CLAIM_DOWNGRADED`, and E040 stays blocked.

## Claim Boundary

This is derived-Simulink evidence only. It cannot support hardware, HIL, silicon, broad mismatch robustness, active Lambda control, neural AI controller validation, or active-phase add/shed claims.
