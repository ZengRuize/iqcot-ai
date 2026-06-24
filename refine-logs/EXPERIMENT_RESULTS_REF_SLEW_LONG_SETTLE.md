# Experiment Results: Long Reference Slew and Settling-Aware Score

## Purpose

The dense `20-80 us` reference-slew sweep showed that the best scanned point for `40A->20A` and `40A->10A` still sat at the upper boundary `80 us`. This follow-up extends the sweep to `80,100,120 us` and then evaluates whether a settling-time penalty changes the preferred slew time.

## Model and Script

- Model copy: `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
- Script: `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`
- Command: `iqcot_dynamic_ref_slew_sweep([80 100 120], "long")`

The original model was not modified. The same controlled current-source load and `From Workspace` `Iph_ref` schedule were used.

## Outputs

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_best_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_wave_samples.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_settle_penalty_best.csv`
- `E:/Desktop/codex/output/figures/fig24_ref_slew_settle_penalty.png`

## Long-Slew Results

| Target load | Long-grid best | Undershoot | Final error | Settling | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20A` | `80 us` | `1.094 mV` | `-0.436 mV` | `14.410 us` | `37.140 ns` | `2.273` |
| `10A` | `80 us` | `4.631 mV` | `-0.551 mV` | `34.286 us` | `82.183 ns` | `8.825` |
| `near-0A` | `120 us` within long-only grid | `9.892 mV` | `-0.574 mV` | `71.408 us` | `118.430 ns` | `16.835` |

When the dense and long grids are combined, the base-score best points remain:

| Target load | Combined base-score best |
|---:|---:|
| `20A` | `80 us` |
| `10A` | `80 us` |
| `near-0A` | `60 us` |

The near-zero case is instructive: `120 us` reduces undershoot to `9.892 mV`, but its longer settling time and larger phase-spacing penalty prevent it from beating the `60 us` point under the original score.

## Settling-Aware Score Sensitivity

Two additional post-processing scores were evaluated:

```text
score_0.05 = score + 0.05 * settle_time_us
score_0.10 = score + 0.10 * settle_time_us
```

| Target load | Base-score best | `score_0.05` best | `score_0.10` best |
|---:|---:|---:|---:|
| `20A` | `80 us` | `30 us` | `30 us` |
| `10A` | `80 us` | `50 us` | `30 us` |
| `near-0A` | `60 us` | `60 us` | `30 us` |

This sensitivity result is more important than a single best number. It shows that the preferred reference slew depends on the system-level objective. If the design prioritizes minimal undershoot and allows slower recovery, longer slew values are attractive. If the design penalizes recovery time, the optimum moves toward faster transitions.

## Interpretation for PIS-IEK and AI Control

The long-slew experiment strengthens the argument for AI as a supervisory parameter scheduler. A fixed hand-tuned slew value is unlikely to be optimal across cut-load depth and objective weights. PIS-IEK can expose the relevant event-domain state and safety metrics, while AI can choose `T_slew` according to the active trade-off among undershoot, settling time, phase-spacing jitter, skip count, and final regulation.

## Boundary

- This is still an open-loop schedule sweep, not AI-in-the-loop Simulink control.
- `80 us`, `60 us`, or `30 us` should not be written as universal optima.
- The evidence supports objective-dependent reference-slew scheduling.

