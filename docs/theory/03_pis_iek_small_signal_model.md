# PIS-IEK Small-Signal Model

## Purpose

PIS-IEK is the phase-indexed saltation integral event-kernel model used for event-domain small-signal reasoning around IQCOT trajectories. It supports:

- current-sharing recovery;
- phase-spacing recovery;
- reentry after large-signal protection;
- mismatch sensitivity;
- ripple-cancellation recovery.

PIS-IEK does not replace the large-signal protection branches. It is the local recovery and balance model once the trajectory is within a valid neighborhood.

## State and Event View

The model treats IQCOT as an event sequence with phase-indexed timing. Each event can perturb:

- phase current state;
- output voltage state;
- event interval `Lambda_i`;
- realized on-time `Ton_actual_i`;
- phase index and active-phase membership.

Small-signal updates estimate how differential timing and on-time trim move current imbalance and phase spacing over subsequent events.

## Actuator Separation

Use this preferred separation unless evidence revises it:

```text
Ton_diff    -> DC current-sharing trim
Lambda_diff -> phase-spacing and ripple-cancellation trim
```

`Ton_diff` should not be overused for fast voltage recovery when `a_U` large-signal recovery is active. `Lambda_diff` should not be used to hide persistent DC current imbalance that requires on-time or parameter correction.

## E030 Evidence Update

The first E030 DCR-mismatch controller chunk supports the actuator separation, but revises the strength of the closed-loop claim.

Validated local setup:

```text
experiment: E030 balance recovery
case: fixed 40 A load, fixed 4 phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
summary: experiments/E030_balance_recovery/e030_research_summary.md
metrics: experiments/E030_balance_recovery/e030_metrics.csv
classification: MODEL_REVISED
```

Measured result:

```text
C0 original DCR-mismatch imbalance = 0.853665 A
C1 Ton_diff-only imbalance = 0.313775 A
C2 Lambda_diff-only imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff imbalance = 0.313775 A
C4 projected balancer imbalance = 0.376221 A
```

Interpretation:

- `Ton_diff` is confirmed as the dominant DC current-sharing actuator in this local mismatch case.
- `Lambda_diff` is not a DC current-sharing actuator in this chunk; it is retained as a phase-spacing / ripple-recovery projection variable.
- Serially inserting a sampled MATLAB Function into the narrow REQ trigger path can drop events and is an implementation error for this model. The current E030 Lambda path is therefore side-band projection/logging only, not a direct trigger gate.
- The C4 projected balancer reduces Ton trim usage (`0.53786` vs `0.865969` for C1/C3) and reduces final Vout error magnitude (`23.494 mV` vs `58.156 mV`), but it does not beat the Ton_diff-only current-imbalance value.

The theory is therefore revised:

```text
Ton_diff provides the primary small-signal DC balance lever.
Safety projection must trade current-sharing speed against voltage error and trim usage.
Lambda_diff requires a non-sampling, event-native IQCOT parameter implementation before it can be claimed as an active phase-spacing actuator.
```

## E030-R1 Projection Retune

E030-R1 retuned the fixed-four-phase `a_S` projection on the same local DCR mismatch case:

```text
experiment: experiments/E030_balance_recovery/R1_projection_retune/
classification: MODEL_REVISED
```

The retained projected Ton-difference rule is:

```text
I_avg = mean(IL_i)
e_I_i = IL_i - I_avg
Delta_Ton_raw_i = -K_T * e_I_i
Delta_Ton_limited_i = clamp(Delta_Ton_raw_i, -T_trim_max, T_trim_max)
Delta_Ton_zero_sum_i = Delta_Ton_limited_i - mean(Delta_Ton_limited_i)
Delta_Ton_i = scale_bound * Delta_Ton_zero_sum_i

scale_bound = min(1, T_trim_max / max_i |Delta_Ton_zero_sum_i|)
```

The final bound projection is required because zero-mean centering after per-phase clamping can otherwise push one phase back outside `T_trim_max`.

R1 evidence:

```text
R1-C1 Ton_diff reference:
  max imbalance = 0.313749 A
  Ton usage = 0.866649
  final Vout error = -58.188 mV
  ripple = 15.311 mV

R1-C4a reduced-KT projection:
  max imbalance = 0.416996 A
  Ton usage = 0.404392
  final Vout error = -3.604 mV
  ripple = 8.128 mV

R1-C4c voltage-aware projection:
  max imbalance = 0.319450 A
  Ton usage = 0.676533
  final Vout error = -29.407 mV
  ripple = 7.121 mV
```

Interpretation:

- `R1-C4a` is the best Pareto candidate by the selected score: it gives less current-sharing improvement than `R1-C1`, but greatly reduces trim effort and voltage-error magnitude.
- `R1-C4c` nearly matches the current-sharing strength of `R1-C1` while reducing ripple and trim usage, but its final voltage error remains larger than `R1-C4a`.
- `R1-C4b` shows that simply reducing `T_trim_max` can weaken balance too much even when the bound is enforced.
- `R1-C4d` is too close to `R1-C1` to count as a distinct retuned controller.

## E030-R2 Current-Sense Mismatch Update

E030-R2 tested the same fixed-four-phase operating point with nominal DCR and biased controller measurements:

```text
experiment: experiments/E030_balance_recovery/R2_current_sense_mismatch/
current-sense gains: [1.05, 0.95, 1.05, 0.95]
classification: MODEL_REVISED
```

The event-domain balance error must now distinguish real and sensed currents:

```text
I_real_i = IL_i
I_sense_i = G_sense_i * IL_i

e_I_real_i = I_real_i - mean(I_real_i)
e_I_sense_i = I_sense_i - mean(I_sense_i)
```

The implemented controller uses `e_I_sense_i`, but the plant objective is bounded `e_I_real_i`. Under R2, the two diverged:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C1 Ton_diff reference:
  real max imbalance = 0.475724 A
  sensed max imbalance = 0.141896 A

R2-C4a reduced-KT projection:
  real max imbalance = 0.317534 A
  sensed max imbalance = 0.195376 A

R2-C4c voltage-aware projection:
  real max imbalance = 0.432627 A
  sensed max imbalance = 0.126599 A
```

Interpretation:

- Current-sense gain mismatch can make `Ton_diff` appear effective to the controller while worsening real current distribution.
- `R2-C4a` reduces the damage versus aggressive `R2-C1`, but it still worsens real imbalance versus `R2-C0`.
- `R2-C4c` improves sensed imbalance most strongly among the projected variants, but it also worsens real imbalance.
- PIS-IEK therefore needs a sensing-confidence term before using sensed `e_I_i` as a balance objective.

Revised local rule:

```text
if current_sense_confidence < confidence_min:
    freeze or strongly downscale Ton_diff
    prefer voltage-safe no-op / low-gain fallback
    require calibration-aware evidence before enabling C4a/C4c
else:
    allow R1-C4a or R1-C4c selector according to voltage/ripple guards
```

## E030-R3 Calibration-Aware Guard Update

E030-R3 tested the guard implied by R2 under the same fixed-four-phase current-sense mismatch:

```text
experiment: experiments/E030_balance_recovery/R3_calibration_aware_guard/
current-sense gains: [1.05, 0.95, 1.05, 0.95]
classification: MODEL_CONFIRMED
```

The revised current input to the balance kernel is:

```text
IL_sense_i = g_i * IL_real_i
IL_est_i = IL_sense_i / g_hat_i

if calibration_enable:
    I_ctrl_i = IL_est_i
elif current_sense_confidence == LOW:
    I_ctrl_i = IL_sense_i
    K_T = fallback_K_T
else:
    I_ctrl_i = IL_sense_i
```

R3 used the ideal calibration boundary `g_hat_i = g_i` for calibrated variants. This is a controlled Simulink hypothesis test, not evidence of practical online calibration accuracy.

Measured local evidence:

```text
R3-C0:
  real max imbalance = 0.036272 A
  sensed max imbalance = 0.538006 A

R3-C1low low-gain fallback:
  real max imbalance = 0.030506 A
  sensed max imbalance = 0.522300 A
  real_no_harm = true

R3-C4a_conf confidence-gated C4a:
  real max imbalance = 0.036272 A
  sensed max imbalance = 0.538006 A
  real_no_harm = true

R3-C4a_cal ideal calibrated C4a:
  real max imbalance = 0.020618 A
  sensed max imbalance = 0.523013 A
  real_no_harm = true

R3-C4c_cal ideal calibrated C4c:
  real max imbalance = 0.025784 A
  sensed max imbalance = 0.527296 A
  real_no_harm = true
```

R3 therefore confirms the local guard principle:

```text
if current_sense_confidence == LOW:
    use no-op or low-gain Ton_diff fallback
elif calibration_enable and voltage/ripple risk is high:
    use calibrated C4a-like projection
elif calibration_enable and current imbalance dominates:
    allow calibrated C4c-like projection under voltage/ripple guards
else:
    fallback
```

This result narrows the R2 failure mode but does not prove broad current-sense robustness. It validates only one gain pattern with ideal `g_hat_i` for the calibrated branches.

## Token Interface

PIS-IEK informs token `a_S`:

```text
K_T
T_trim_max
K_Lambda
Lambda_trim_max
balance_recovery_rate
phase_spacing_weight
current_balance_weight
```

The safety projection clamps differential trims and may slow recovery when voltage protection, current limits, or active-phase transitions are active.

## Validity

PIS-IEK claims are small-signal or recovery claims unless validated against large-signal derived models. Mismatch studies must include L, DCR, Ron, current-sense gain, and driver-delay perturbations before claiming robustness.

After E030-R3, PIS-IEK may be used to motivate the `a_S` controller architecture, to claim local DCR-mismatch balance trade-offs, and to claim that one local current-sense mismatch pattern was made real-current no-harm by a confidence/calibration guard in the ideal derived model. It may not yet be used to claim robust mismatch recovery across L, DCR, Ron, current-sense gain, and driver-delay families.
