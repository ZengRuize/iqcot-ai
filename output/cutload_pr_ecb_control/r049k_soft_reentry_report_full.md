# R049K PR-ECB Deferred Post-Active Pulse-Inhibit Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049K copy of R049I with inherited repaired lower bound and added request-path short soft-reentry gate.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2 short soft-reentry proxy: `delay=70ns`, `window=1.69us`; Ton truncation disabled.
- A0 baseline: same model, negative inhibit window; Ton truncation disabled.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049k_soft_reentry_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049k_soft_reentry_comparison_full.csv`
- Wave snapshots: `output/data/*_r049k_soft_reentry_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | inhibit us | skipped REQ | first inhibit us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049k_20A_off0p050_a0 | A0_no_inhibit | 0.050 | 2.1103 | 9.4540 | 52.0000 | 0.0000 | 0 | NaN | -0.8909 | -0.4397 |
| r049k_20A_off0p050_a2_soft_reentry | A2_short_soft_reentry | 0.050 | 2.0977 | 0.4840 | 52.0000 | 1.6900 | 1 | 0.0700 | -1.0414 | -0.4422 |
| r049k_20A_off0p105_a0 | A0_no_inhibit | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0 | NaN | -0.8991 | -0.4344 |
| r049k_20A_off0p105_a2_soft_reentry | A2_short_soft_reentry | 0.105 | 2.0316 | 12.1150 | 0.0000 | 1.6900 | 1 | 0.0710 | -0.8444 | -0.4306 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 inhibit us | A2 skipped REQ | A2 first inhibit us | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | 2.0977 | 0.0126 | 0.0000 | 1.6900 | 1 | 0.0700 | -0.1504 | -0.0026 |
| 0.105 | 2.0936 | 2.0316 | 0.0620 | 0.0000 | 1.6900 | 1 | 0.0710 | 0.0547 | 0.0037 |

## Decision

```text
MODEL_REVISED
```

This preliminary runner decision is aligned with the final R049H three-window audit for this R049K soft-reentry proxy chunk.
