# AI Supervisory Reference-Slew Training Targets

**Date**: 2026-06-20
**Source**: `output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`
**Output CSV**: `output/iqcot_ai_supervisor_training_targets.csv`

## Purpose

This table converts the existing four-phase IQCOT Simulink reference-slew sweep into supervised labels for a slow AI supervisory layer. The label is `T_slew`; the inner IQCOT event generator remains unchanged.

## Feature / Label Definition

- Features: target load after cut, normalized load drop, settling penalty weight, FPGA AI latency, and event-domain delay count.
- Label: `selected_ref_slew_us`, chosen by minimizing the objective-specific score over the existing switching-level sweep grid.
- Deployment delay feature: `delay_events = ceil(tau_AI / 0.5us)` is included so an AI policy can be trained in the same event coordinates used by the PIS-IEK delay surrogate.

## Oracle Labels

| target load | alpha=0 | alpha=0.05 | alpha=0.10 |
|---:|---:|---:|---:|
| 20A | 80 us | 30 us | 30 us |
| 10A | 80 us | 50 us | 30 us |
| near-0A | 60 us | 60 us | 30 us |

## Interpretation

- `T_slew` is objective-sensitive: labels change from `80/80/60 us` at alpha=0 to `30/50/60 us` at alpha=0.05 and `30/30/30 us` at alpha=0.10.
- `tau_AI` does not change the offline Simulink label in this table; it is a deployment-context feature. A later AI-in-loop Simulink validation must verify whether delay-aware policies preserve the same ordering on switching waveforms.
- This is a training-target bridge, not proof that AI has outperformed IQCOT in hardware.