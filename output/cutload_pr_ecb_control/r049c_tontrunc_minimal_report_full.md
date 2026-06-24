# R049C PR-ECB Minimal Ton-Truncation Chunk

Run label: `full`

## Scope and hypothesis

- Model version: GAE-IQCOT R047 + R049A scaffold + R049C command-path Ton truncation.
- Hypothesis: shortening the COT-cell Ton command during the first cut-load window reduces the first peak for the active-HS offset and does not worsen the post-turnoff offset.
- Expected failure mode: the COT cell may sample Ton only at pulse start, so command-path truncation may not terminate an already-active high-side pulse.
- Metrics: peak overshoot, first-peak time, truncation duration, Ton-min hit count, secondary undershoot, final error.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049c_tontrunc.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049c_tontrunc_minimal_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049c_tontrunc_minimal_comparison_full.csv`
- Wave snapshots: `output/data/*_r049c_tontrunc_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | trunc us | trunc edges | rem Ton4 ns | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| r049c_near0_off0p050_a0 | A0_no_trunc | 0.050 | 6.2586 | 1.4000 | 0.0000 | 0 | 52.0000 | -8.2934 | -0.5396 |
| r049c_near0_off0p050_a2_tontrunc | A2_ton_trunc | 0.050 | 5.4926 | 1.2680 | 2.0000 | 1 | 2.0000 | -1.1669 | -0.5768 |
| r049c_near0_off0p105_a0 | A0_no_trunc | 0.105 | 5.9603 | 1.3450 | 0.0000 | 0 | 0.0000 | -7.2482 | -0.5695 |
| r049c_near0_off0p105_a2_tontrunc | A2_ton_trunc | 0.105 | 5.9603 | 1.3450 | 2.0000 | 1 | 0.0000 | -7.2482 | -0.5695 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | A2 trunc us | A2 Ton-min hits | A2-A0 undershoot mV |
|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 6.2586 | 5.4926 | 0.7660 | 2.0000 | 4000 | 7.1266 |
| 0.105 | 5.9603 | 5.9603 | 0.0000 | 2.0000 | 4000 | 0.0000 |

## Decision

```text
MODEL_CONFIRMED
```

This decision applies only to this minimal R049C chunk.
