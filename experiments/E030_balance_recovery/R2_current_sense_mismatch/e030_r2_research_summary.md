# E030-R2 Current-Sense Mismatch Research Summary

Date: 2026-06-29

## Hypothesis

R2 tests whether the R1-C4a/R1-C4c `a_S` projection trade-off remains meaningful when the controller sees biased phase-current measurements. Real `IL_i` and sensed `IL_sense_i` are reported separately.

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Model Copy Paths

- `R2-C0`: `E:/Desktop/codex/models/derived/E030_R2_C0_current_sense_from_ideal_iqcot_20260629.slx`
- `R2-C1`: `E:/Desktop/codex/models/derived/E030_R2_C1_current_sense_from_ideal_iqcot_20260629.slx`
- `R2-C4a`: `E:/Desktop/codex/models/derived/E030_R2_C4a_current_sense_from_ideal_iqcot_20260629.slx`
- `R2-C4c`: `E:/Desktop/codex/models/derived/E030_R2_C4c_current_sense_from_ideal_iqcot_20260629.slx`

## External Load And Mismatch

Fixed external `40A` current sink; nominal power-stage DCR; current-sense gain pattern `[+5% -5% +5% -5%]`. Load current and sensing mismatch are validation inputs, not AI actions.

## Controller Variants Compared

`R2-C0`, `R2-C1`, `R2-C4a`, `R2-C4c`.

## Scores

Lower is better. Both scores use weights `wI=0.40`, `wV=0.20`, `wR=0.15`, `wT=0.15`, `wP=0.10`.

```text
score_real = 0.40 * real_current_imbalance / C0_real_current_imbalance
      + 0.20 * abs(final_Vout_error_mV) / 60
      + 0.15 * Vout_ripple_pp_mV / 16
      + 0.15 * Ton_trim_usage
      + 0.10 * phase_spacing_std_ns / 50

score_sensed uses sensed_current_imbalance in the first term.
```

## Metrics Table

Metrics CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv`

| Variant | Success | Real max imb A | Sensed max imb A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C0 | 1 | 0.036272 | 0.538006 | 1.13739 | -1.81159 | 0 | 340 | 0 | 26.961 | 0 | 0.470624 | 0.470624 | baseline |
| R2-C1 | 1 | 0.475724 | 0.141896 | 15.0557 | -58.8678 | 0.871935 | 353 | 0 | 4.12679e-10 | 0 | 5.71434 | 0.573661 | ton_diff_reference |
| R2-C4a | 1 | 0.317534 | 0.195376 | 8.60658 | -7.4593 | 0.401338 | 352 | 0 | 5.30483 | 0 | 3.67806 | 0.321621 | sensed_real_divergence |
| R2-C4c | 1 | 0.432627 | 0.126599 | 7.54143 | -29.6157 | 0.681135 | 353 | 0 | 4.12679e-10 | 0 | 5.0425 | 0.365715 | sensed_real_divergence |

## Best Retuned Candidate

No C4 retuned variant satisfied all Pareto guard checks.

## Interpretation

R2-C0 real max imbalance is `0.036272 A` and sensed max imbalance is `0.538006 A`. R2-C1 Ton_diff reference gives real max imbalance `0.475724 A`, sensed max imbalance `0.141896 A`, Ton usage `0.871935`, and final Vout error `-58.8678 mV`.

| Variant | Real imb reduction vs C0 A | Sensed imb reduction vs C0 A | Real score delta vs C1 | Sensed score delta vs C1 | Ton usage delta vs C1 | Final-error magnitude delta vs C1 mV |
|---|---:|---:|---:|---:|---:|---:|
| R2-C4a | -0.281262 | 0.34263 | -2.03628 | -0.25204 | -0.470596 | -51.4085 |
| R2-C4c | -0.396355 | 0.411407 | -0.67184 | -0.207946 | -0.1908 | -29.2521 |

## Failure Or Trade-Off Analysis

At least one projected variant improves the controller-observed score without a matching real-current Pareto advantage; add a sensing-confidence or calibration-aware guard before E040.

## Classification

`MODEL_REVISED`

## Claim Boundary

This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad mismatch robustness, active Lambda control, or active-phase add/shed behavior.

## Next Smallest Useful Experiment

Add or refine a current-sense-confidence / calibration-aware guard before E040.
