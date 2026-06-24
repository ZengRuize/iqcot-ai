# R049D PR-ECB Ton-Truncation Hold-Out Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049D copy of the R049C command-path Ton-truncation model.
- Hold-out: `40A -> 10A` at offsets `0.05us` and `0.105us`.
- Hypothesis: the active-HS offset should benefit from Ton truncation without worsening the post-turnoff offset or secondary response.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049d_tontrunc_holdout_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049d_tontrunc_holdout_comparison_full.csv`
- Wave snapshots: `output/data/*_r049d_tontrunc_holdout_wave.csv`

## Per-case results

| case | ctrl | target A | offset us | peak mV | t_peak us | trunc us | trunc edges | rem Ton4 ns | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049d_10A_off0p050_a0 | A0_no_trunc | 10.0 | 0.050 | 3.9908 | 0.9620 | 0.0000 | 0 | 52.0000 | -3.1821 | -0.5471 |
| r049d_10A_off0p050_a2_tontrunc | A2_ton_trunc | 10.0 | 0.050 | 3.3873 | 0.8280 | 1.8700 | 1 | 2.0000 | -1.1542 | -0.5781 |
| r049d_10A_off0p105_a0 | A0_no_trunc | 10.0 | 0.105 | 3.7607 | 0.9070 | 0.0000 | 0 | 0.0000 | -2.1136 | -0.5993 |
| r049d_10A_off0p105_a2_tontrunc | A2_ton_trunc | 10.0 | 0.105 | 3.7607 | 0.9070 | 2.0000 | 1 | 0.0000 | -2.1136 | -0.5993 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | A2 trunc us | A2 Ton-min hits | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 3.9908 | 3.3873 | 0.6036 | 1.8700 | 3740 | 2.0279 | -0.0310 |
| 0.105 | 3.7607 | 3.7607 | 0.0000 | 2.0000 | 4000 | 0.0000 | 0.0000 |

## Decision

```text
MODEL_CONFIRMED
```

This decision applies only to this R049D hold-out chunk.
