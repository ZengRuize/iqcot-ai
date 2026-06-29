# E030-R1 Projection-Retune Research Summary

Date: 2026-06-29

## Hypothesis

R1 tests whether projected `a_S` can trade a small amount of current-sharing performance for lower trim effort, smaller final voltage error, bounded ripple, and intact phase/event rhythm.

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Model Copy Paths

- `R1-C0`: `E:/Desktop/codex/models/derived/E030_R1_C0_projection_retune_from_ideal_iqcot_20260629.slx`
- `R1-C1`: `E:/Desktop/codex/models/derived/E030_R1_C1_projection_retune_from_ideal_iqcot_20260629.slx`
- `R1-C4a`: `E:/Desktop/codex/models/derived/E030_R1_C4a_projection_retune_from_ideal_iqcot_20260629.slx`
- `R1-C4b`: `E:/Desktop/codex/models/derived/E030_R1_C4b_projection_retune_from_ideal_iqcot_20260629.slx`
- `R1-C4c`: `E:/Desktop/codex/models/derived/E030_R1_C4c_projection_retune_from_ideal_iqcot_20260629.slx`
- `R1-C4d`: `E:/Desktop/codex/models/derived/E030_R1_C4d_projection_retune_from_ideal_iqcot_20260629.slx`

## External Load And Mismatch

Fixed external `40A` current sink; `DCR_L1/L3 = +10%`, `DCR_L2/L4 = -10%`. Load current and DCR mismatch are validation inputs, not AI actions.

## Controller Variants Compared

`R1-C0`, `R1-C1`, `R1-C4a`, `R1-C4b`, `R1-C4c`, `R1-C4d`.

## Pareto Score

Lower is better. Weights: `wI=0.40`, `wV=0.20`, `wR=0.15`, `wT=0.15`, `wP=0.10`.

```text
score = 0.40 * current_imbalance / C0_current_imbalance
      + 0.20 * abs(final_Vout_error_mV) / 60
      + 0.15 * Vout_ripple_pp_mV / 16
      + 0.15 * Ton_trim_usage
      + 0.10 * phase_spacing_std / 50
```

## Metrics Table

Metrics CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv`

| Variant | Success | Max imbalance A | RMS imbalance A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C0 | 1 | 0.853665 | 0.830663 | 1.3133 | -2.27703 | 0 | 339 | 0 | 42.7227 | 0 | 0.505348 | baseline |
| R1-C1 | 1 | 0.313749 | 0.264781 | 15.3112 | -58.1882 | 0.866649 | 353 | 0 | 4.12679e-10 | 0 | 0.614513 | ton_diff_reference |
| R1-C4a | 1 | 0.416996 | 0.411139 | 8.12771 | -3.60374 | 0.404392 | 353 | 0 | 9.14654 | 0 | 0.362552 | pareto_candidate |
| R1-C4b | 1 | 0.729613 | 0.721038 | 17.3191 | -32.9314 | 1 | 353 | 0 | 4.12679e-10 | 0 | 0.76401 | tradeoff_or_guard_issue |
| R1-C4c | 1 | 0.31945 | 0.308364 | 7.121 | -29.407 | 0.676533 | 353 | 0 | 4.12679e-10 | 0 | 0.415946 | pareto_candidate |
| R1-C4d | 1 | 0.313793 | 0.265373 | 15.2172 | -58.1561 | 0.865968 | 353 | 0 | 4.12679e-10 | 0 | 0.613443 | tradeoff_or_guard_issue |

## Best Retuned Candidate

`R1-C4a`

## Interpretation

R1-C0 max current imbalance is `0.853665 A`; R1-C1 Ton_diff reference is `0.313749 A` with Ton usage `0.866649` and final Vout error `-58.1882 mV`.

| Variant | Imbalance reduction vs C0 A | Ton usage delta vs C1 | Final-error magnitude delta vs C1 mV | Ripple delta vs C1 mV |
|---|---:|---:|---:|---:|
| R1-C4a | 0.43667 | -0.462256 | -54.5845 | -7.18345 |
| R1-C4b | 0.124053 | 0.133351 | -25.2568 | 2.0079 |
| R1-C4c | 0.534216 | -0.190116 | -28.7812 | -8.19016 |
| R1-C4d | 0.539872 | -0.000680402 | -0.0321206 | -0.093996 |

`R1-C4d` is numerically close to `R1-C1`; its trim and final-error changes are below the minimum improvement margins used for a clear Pareto candidate. It is therefore treated as a trade-off / guard issue, not as a distinct retuned controller.

## Failure Or Trade-Off Analysis

A retuned projected C4 variant shows a defensible Pareto advantage versus C1 under the selected score, but Lambda remains side-band/logging only, so active Lambda and broad robustness claims remain revised.

## Classification

`MODEL_REVISED`

## Claim Boundary

This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad mismatch robustness, active Lambda control, or active-phase add/shed behavior.

## Next Smallest Useful Experiment

Use the best R1 candidate to update the `a_S` projection, then decide whether one additional DCR/current-sense mismatch case is warranted before E040.
