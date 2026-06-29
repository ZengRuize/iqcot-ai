# E030 Balance-Recovery Research Summary

Date: 2026-06-29

## Hypothesis

PIS-IEK predicts `Ton_diff` as the dominant DC current-sharing actuator and `Lambda_diff` as a phase-spacing/ripple-recovery actuator. This first chunk tests one DCR mismatch pattern at fixed `40A` load.

## Model Copy Path

- `C0`: `E:/Desktop/codex/models/derived/E030_C0_dcr_obs_iqcot_20260629.slx`
- `C1`: `E:/Desktop/codex/models/derived/E030_C1_tondiff_iqcot_20260629.slx`
- `C2`: `E:/Desktop/codex/models/derived/E030_C2_lambdadiff_iqcot_20260629.slx`
- `C3`: `E:/Desktop/codex/models/derived/E030_C3_ton_lambda_iqcot_20260629.slx`
- `C4`: `E:/Desktop/codex/models/derived/E030_C4_pisiek_proj_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Modified Blocks/Signals

- C0: observability plus DCR mismatch injected through variables.
- C1: zero-mean `Ton_diff` current-sharing trim.
- C2: bounded side-band `Lambda_diff` event-spacing projection/logging proxy.
- C3: C1 and C2 combined.
- C4: conservative PIS-IEK projected balancer; projected Lambda fallback is logged but does not gate REQ pulses.

## External Load Profile

Constant `40A`; load current remains an external validation input.

## Controller Variants Compared

`C0`, `C1`, `C2`, `C3`, `C4`.

## Metrics Table

Metrics CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/e030_metrics.csv`

| Variant | Success | Max imbalance A | RMS imbalance A | Phase spacing std ns | Ripple mV | Eff. fsw Hz | Ton usage | Lambda usage | Settling us | Final Vout err mV | Clamp | Fallback | Order error |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C0 | 1 | 0.853665 | 0.830663 | 42.7227 | 1.3133 | 498529 | 0 | 0 | NaN | -2.27703 | 0 | 0 | 0 |
| C1 | 1 | 0.313775 | 0.265364 | 4.12679e-10 | 15.2173 | 519118 | 0.865969 | 0 | NaN | -58.1561 | 0 | 0 | 0 |
| C2 | 1 | 0.853665 | 0.830663 | 42.7227 | 1.3133 | 498529 | 0 | 0.75 | NaN | -2.27703 | 78 | 0 | 0 |
| C3 | 1 | 0.313775 | 0.265364 | 4.12679e-10 | 15.2173 | 519118 | 0.865969 | 0.75 | NaN | -58.1561 | 10 | 0 | 0 |
| C4 | 1 | 0.376221 | 0.333885 | 4.12679e-10 | 16.0747 | 519118 | 0.53786 | 0 | NaN | -23.4942 | 10 | 10 | 0 |

## Waveform Interpretation

C0 max current imbalance is `0.853665 A`. Reductions relative to C0:

| Variant | Imbalance reduction A | Phase-spacing std delta ns | Ripple delta mV |
|---|---:|---:|---:|
| C1 | 0.539891 | -42.7227 | 13.904 |
| C2 | 0 | 0 | 0 |
| C3 | 0.539891 | -42.7227 | 13.904 |
| C4 | 0.477444 | -42.7227 | 14.7614 |

## Failure Or Trade-Off Analysis

Ton_diff or C4 improved current sharing, but the result needs a narrower projection or trim budget before claiming robust balance recovery.

## Classification

`MODEL_REVISED`

## Theory Documents Updated

Updated `docs/theory/03_pis_iek_small_signal_model.md`, `docs/theory/04_ai_action_space_and_projection.md`, and `docs/theory/06_claim_boundaries.md` with the E030 `MODEL_REVISED` boundary.

## Claim Boundary Updated

Treat this as E030 derived-Simulink evidence only. It is not hardware, HIL, board-level, or silicon evidence.

## Next Smallest Useful Experiment

Retune `T_trim_max`, `K_T`, and the Lambda event-spacing proxy before broad mismatch grids.
