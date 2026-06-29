# E030-R1 Projection-Retune Hypothesis

Date: 2026-06-29

## Baseline

All R1 validation derives from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` is never modified directly. Each R1 model is a derived copy created through MATLAB/Simulink APIs and saved under:

```text
models/derived/E030_R1_<variant>_projection_retune_from_ideal_iqcot_20260629.slx
```

## Purpose

E030 first chunk produced `MODEL_REVISED`: `Ton_diff` improved DC current sharing but the aggressive C1/C3 variants had high trim usage and large final Vout error; C4 reduced trim usage and final Vout error but did not beat C1/C3 on current imbalance.

E030-R1 retunes the `a_S` projection to test whether a PIS-IEK projected balancer has a defensible Pareto trade-off:

```text
current-sharing improvement
vs
Ton trim effort
vs
final Vout error
vs
output ripple
vs
phase/event rhythm
```

## Fixed Operating Point

```text
load: fixed 40 A external current sink
active phases: fixed four-phase
DCR nominal: 0.01 ohm
DCR_L1/L3: +10% -> 0.011 ohm
DCR_L2/L4: -10% -> 0.009 ohm
```

The mismatch and load are plant/validation inputs, not AI actions.

## Variants

```text
R1-C0  original IQCOT with DCR mismatch
R1-C1  previous Ton_diff-only reference
R1-C4a projected balancer with reduced K_T
R1-C4b projected balancer with reduced T_trim_max
R1-C4c voltage-error-aware Ton trim scaling
R1-C4d ripple-aware Ton trim scaling plus post-run phase/REQ audit
```

No R1 variant directly commands QH/QL gates. No R1 variant commands load-current slew.

## Projection Model

Base current-sharing trim:

```text
I_avg = mean(IL_i)
e_I_i = IL_i - I_avg
Delta_Ton_raw_i = -K_T * e_I_i
Delta_Ton_limited_i = clamp(Delta_Ton_raw_i, -T_trim_max, T_trim_max)
Delta_Ton_i = Delta_Ton_limited_i - mean(Delta_Ton_limited_i)
```

R1-C4c applies voltage-error-aware scaling:

```text
e_V = Vout - Vref
voltage_scale = clamp(1 - max(abs(e_V) - V_error_budget, 0) /
                          (V_error_hard_limit - V_error_budget),
                      min_scale, 1)
Delta_Ton_i = voltage_scale * Delta_Ton_i
```

R1-C4d applies an online ripple-envelope scaling:

```text
ripple_est = Vout_max_window - Vout_min_window
ripple_scale = clamp(1 - max(ripple_est - ripple_budget, 0) /
                         (ripple_hard_limit - ripple_budget),
                     min_scale, 1)
Delta_Ton_i = ripple_scale * Delta_Ton_i
```

The phase-spacing and REQ-loss parts of R1-C4d are evaluated in postprocess. If phase order is broken or REQ count drops versus R1-C0, the variant cannot support an active-control claim.

## Lambda Boundary

The previous sampled serial Lambda implementation dropped narrow REQ pulses and was rejected. R1 does not implement active Lambda actuation. `Lambda_trim_usage` is retained as a metric field, but active Lambda claims remain forbidden until an event-native Lambda implementation passes a separate micro-audit.

## Metrics

R1 reports:

```text
max_current_imbalance_A
rms_current_imbalance_A
mean_IL1_A..mean_IL4_A
rms_IL1_A..rms_IL4_A
phase_spacing_std
phase_order_error_rate
Vout_ripple_pp_mV
effective_switching_frequency_Hz
Ton_trim_usage
Lambda_trim_usage
final_Vout_error_mV
current_imbalance_settling_us
guard_clamp_count
fallback_count
REQ_count
dropped_REQ_count
pareto_score
classification_hint
```

The Pareto score is only a secondary summary:

```text
score = 0.40 * current_imbalance / C0_current_imbalance
      + 0.20 * abs(final_Vout_error_mV) / 60
      + 0.15 * Vout_ripple_pp_mV / 16
      + 0.15 * Ton_trim_usage
      + 0.10 * phase_spacing_std / 50
```

Lower is better. The score does not by itself prove `MODEL_CONFIRMED`.

## Classification Rule

```text
MODEL_CONFIRMED:
  A retuned projected C4 variant improves current imbalance versus R1-C0,
  uses less Ton trim than R1-C1, has smaller final Vout error magnitude than
  R1-C1, keeps ripple and phase/event rhythm bounded, and has no REQ pulse loss.

MODEL_REVISED:
  Retuned C4 improves some metrics but depends on score weights, still needs
  projection tuning, or Lambda remains side-band only.

IMPLEMENTATION_ISSUE:
  Derived model wiring, DCR injection, trim path, logging, REQ counting, or
  postprocessing is unreliable.

CLAIM_DOWNGRADED:
  Retuned projected balancing does not improve current sharing or worsens
  voltage/ripple/phase behavior enough to erase the trade-off.
```

## Non-Claims

- No broad mismatch robustness claim.
- No hardware, HIL, board-level, or silicon claim.
- No active Lambda closed-loop claim.
- No active-phase add/shed claim.
- No neural AI controller claim.
