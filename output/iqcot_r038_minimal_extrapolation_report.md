# R038 Minimal Extrapolation Derived-Simulink Validation

## Scope

R038 executes the 9-row minimal extrapolation matrix created by R037 on the
derived delayed-reference Simulink runner. It checks local robustness around
`46us@1.25us`, `50us@1.5us`, `54us@1.75us`, and the `tau_AI=2us` foldback
boundary. The original `.slx` is not modified.

## Execution

- Rows executed: `9`
- Successful rows: `9`
- Chunks: `rows001_003`, `rows004_006`, `rows007_009`
- Figure: `figures/fig51_r038_minimal_extrapolation.svg`

## Context Summary

| tau_ai_us | n_candidates_after_r038 | best_slew_us_after_r038 | best_score_after_r038 | dense_30_score | best_minus_dense_score | old_r037_slew_us | best_minus_old_r037_score | interpretation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1.250 | 8 | 46.000 | 2.146 | 4.989 | -2.843 | 46.000 | 0.000 | R038 42/44us probes do not beat the R036 46us folded commit. |
| 1.500 | 7 | 50.000 | 2.141 | 4.312 | -2.171 | 50.000 | 0.000 | R038 46/54us probes do not beat the existing 50us center pocket; 46us shows skip risk. |
| 1.750 | 8 | 54.000 | 2.142 | 4.317 | -2.175 | 54.000 | 0.000 | R038 52/56us probes do not beat the R036 54us folded commit. |
| 2.000 | 10 | 48.000 | 2.072 | 2.093 | -0.020 | 30.000 | -0.020 | R038 reveals a near-tie foldback band: 48us is slightly below 30us, but the margin is too small to remove dense fallback. |

## Interpretation

- `tau_AI=1.25us`: `42/44us` do not beat the already validated `46us` folded commit.
- `tau_AI=1.5us`: `46us` triggers one skip and is much worse; `54us` is also worse than the `50us` anchor.
- `tau_AI=1.75us`: `52/56us` do not beat the already validated `54us` folded commit.
- `tau_AI=2.0us`: `48us` is slightly better than the previous `30us` dense fallback by about `0.020` score, while `44us` is nearly tied. This should be written as a near-tie foldback band, not as proof that `30us` is globally wrong.

## Boundary

These are derived-Simulink delayed-reference results, not hardware/HIL
validation. AI remains a supervisory parameter scheduler. R038 does not prove a
global `T_slew` optimum and does not prove that the current `r_hat` predictor is
independently generalizable.
