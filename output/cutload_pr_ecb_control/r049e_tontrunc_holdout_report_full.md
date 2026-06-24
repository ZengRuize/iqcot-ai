# R049E PR-ECB Ton-Truncation Mild Hold-Out Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049E copy of the R049D/R049C command-path Ton-truncation model.
- Hold-out: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- Hypothesis: the active-HS offset should still benefit, but with smaller magnitude, while the post-turnoff offset should remain unchanged.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049e_tontrunc_holdout_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049e_tontrunc_holdout_comparison_full.csv`
- Wave snapshots: `output/data/*_r049e_tontrunc_holdout_wave.csv`

## Per-case results

| case | ctrl | target A | offset us | peak mV | t_peak us | trunc us | trunc edges | rem Ton4 ns | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049e_20A_off0p050_a0 | A0_no_trunc | 20.0 | 0.050 | 2.1103 | 9.4540 | 0.0000 | 0 | 52.0000 | -0.8909 | -0.4397 |
| r049e_20A_off0p050_a2_tontrunc | A2_ton_trunc | 20.0 | 0.050 | 2.1103 | 9.4540 | 0.5180 | 1 | 52.0000 | -0.8909 | -0.4397 |
| r049e_20A_off0p105_a0 | A0_no_trunc | 20.0 | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0 | 0.0000 | -0.8991 | -0.4344 |
| r049e_20A_off0p105_a2_tontrunc | A2_ton_trunc | 20.0 | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0 | 0.0000 | -0.8991 | -0.4344 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | A2 trunc us | A2 Ton-min hits | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | 2.1103 | 0.0000 | 0.5180 | 1036 | 0.0000 | 0.0000 |
| 0.105 | 2.0936 | 2.0936 | 0.0000 | 0.0000 | 0 | 0.0000 | 0.0000 |

## Decision

```text
CLAIM_DOWNGRADED
```

This decision applies only to this R049E mild hold-out chunk.
