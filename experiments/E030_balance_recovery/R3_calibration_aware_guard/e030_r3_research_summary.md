# E030-R3 Current-Sense Mismatch Research Summary

Date: 2026-06-29

## Hypothesis

R3 tests whether a current-sense-confidence or calibration-aware `a_S` guard can prevent sensed-current optimization from worsening real phase-current balance. Real `IL_i`, sensed `IL_sense_i`, and estimated `IL_est_i` are reported separately.

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Model Copy Paths

- `R3-C0`: `E:/Desktop/codex/models/derived/E030_R3_C0_cal_guard_from_ideal_iqcot_20260629.slx`
- `R3-C1low`: `E:/Desktop/codex/models/derived/E030_R3_C1low_cal_guard_from_ideal_iqcot_20260629.slx`
- `R3-C4a_conf`: `E:/Desktop/codex/models/derived/E030_R3_C4a_conf_cal_guard_from_ideal_iqcot_20260629.slx`
- `R3-C4a_cal`: `E:/Desktop/codex/models/derived/E030_R3_C4a_cal_from_ideal_iqcot_20260629.slx`
- `R3-C4c_cal`: `E:/Desktop/codex/models/derived/E030_R3_C4c_cal_from_ideal_iqcot_20260629.slx`

## External Load And Mismatch

Fixed external `40A` current sink; nominal power-stage DCR; current-sense gain pattern `[+5% -5% +5% -5%]`. Calibrated variants use ideal `g_hat_i = g_i` as a boundary case. Load current and sensing mismatch are validation inputs, not AI actions.

## Controller Variants Compared

`R3-C0`, `R3-C1low`, `R3-C4a_conf`, `R3-C4a_cal`, `R3-C4c_cal`.

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

Metrics CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv`

| Variant | Success | Real max imb A | Sensed max imb A | Est IL1 A | Est IL2 A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | No-harm | Confidence | Cal | Score real | Score sensed | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| R3-C0 | 1 | 0.036272 | 0.538006 | 9.96251 | 9.97348 | 1.13739 | -1.81159 | 0 | 340 | 0 | 1 | LOW | 0 | 0.470624 | 0.470624 | baseline |
| R3-C1low | 1 | 0.0305063 | 0.5223 | 10.007 | 9.97664 | 1.08155 | -1.83888 | 0.0207844 | 340 | 0 | 1 | LOW | 0 | 0.408972 | 0.460878 | low_gain_no_harm |
| R3-C4a_conf | 1 | 0.036272 | 0.538006 | 9.96251 | 9.97348 | 1.13739 | -1.81159 | 0 | 340 | 0 | 1 | LOW | 0 | 0.470624 | 0.470624 | confidence_gated_no_harm |
| R3-C4a_cal | 1 | 0.020618 | 0.523013 | 10.0692 | 10.0511 | 8.58179 | -5.24904 | 0.371231 | 352 | 0 | 1 | HIGH | 1 | 0.393384 | 0.554866 | calibrated_no_harm |
| R3-C4c_cal | 1 | 0.0257836 | 0.527296 | 9.98173 | 10.0239 | 7.55869 | -29.5722 | 0.650867 | 353 | 0 | 1 | HIGH | 1 | 0.551403 | 0.659104 | calibrated_no_harm |

## Best Retuned Candidate

`R3-C4a_cal`

## Interpretation

R3-C0 real max imbalance is `0.036272 A` and sensed max imbalance is `0.538006 A`. The real-current no-harm threshold is `0.056272 A`.

| Variant | Real imb delta vs C0 A | Sensed imb delta vs C0 A | Real no-harm | Fallback count | Calibration | Hint |
|---|---:|---:|---:|---:|---:|---|
| R3-C1low | -0.00576576 | -0.0157062 | 1 | 4251 | 0 | low_gain_no_harm |
| R3-C4a_conf | 0 | 0 | 1 | 4251 | 0 | confidence_gated_no_harm |
| R3-C4a_cal | -0.015654 | -0.0149931 | 1 | 0 | 1 | calibrated_no_harm |
| R3-C4c_cal | -0.0104884 | -0.0107101 | 1 | 0 | 1 | calibrated_no_harm |

## Failure Or Trade-Off Analysis

At least one calibration-aware or confidence-gated a_S variant satisfies the real-current no-harm guard with no REQ loss and no phase-order error. This supports keeping E040 blocked only until the guarded selector is frozen.

## Classification

`MODEL_CONFIRMED`

## Claim Boundary

This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad mismatch robustness, active Lambda control, or active-phase add/shed behavior.

## Next Smallest Useful Experiment

Freeze the local guarded `a_S` selector before preparing E040; keep Lambda active-control claims disabled.
