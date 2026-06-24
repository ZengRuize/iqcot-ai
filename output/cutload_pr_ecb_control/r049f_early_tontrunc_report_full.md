# R049F PR-ECB Early Ton-Truncation Trigger-Timing Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049F copy of R049E with Ton-truncation flag changed to load-step-synchronous time-window logic.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2 early trigger: `Tton_trunc_min=5ns`, `Tton_trunc_window=80ns`.
- A0 baseline: same model, negative time window disables truncation.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049f_early_tontrunc_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049f_early_tontrunc_comparison_full.csv`
- Wave snapshots: `output/data/*_r049f_early_tontrunc_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | trunc us | first trunc us | qh4 first trunc | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049f_20A_off0p050_a0 | A0_no_trunc | 0.050 | 2.1103 | 9.4540 | 52.0000 | 0.0000 | NaN | NaN | -0.8909 | -0.4397 |
| r049f_20A_off0p050_a2_early | A2_early_ton_trunc | 0.050 | -184.1030 | 80.0000 | 0.0000 | 0.0800 | 0.0000 | 0 | -184.1030 | -239.1723 |
| r049f_20A_off0p105_a0 | A0_no_trunc | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | NaN | NaN | -0.8991 | -0.4344 |
| r049f_20A_off0p105_a2_early | A2_early_ton_trunc | 0.105 | -189.3089 | 79.9990 | 0.0000 | 0.0800 | 0.0010 | 0 | -189.3089 | -241.9473 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 first trunc us | A2 qh4 first trunc | A2-A0 undershoot mV |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | -184.1030 | 186.2133 | 52.0000 | 0.0000 | 0 | -183.2121 |
| 0.105 | 2.0936 | -189.3089 | 191.4024 | 0.0000 | 0.0010 | 0 | -188.4097 |

## Decision

```text
MODEL_REVISED
```

This decision applies only to this R049F trigger-timing diagnostic chunk.
