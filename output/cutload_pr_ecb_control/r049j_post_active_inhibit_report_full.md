# R049J PR-ECB Deferred Post-Active Pulse-Inhibit Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049J copy of R049I with inherited repaired lower bound and added request-path post-active inhibit gate.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2 deferred post-active pulse inhibit: `delay=70ns`, `window=1.93us`; Ton truncation disabled.
- A0 baseline: same model, negative inhibit window; Ton truncation disabled.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049j_post_active_inhibit_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049j_post_active_inhibit_comparison_full.csv`
- Wave snapshots: `output/data/*_r049j_post_active_inhibit_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | inhibit us | skipped REQ | first inhibit us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049j_20A_off0p050_a0 | A0_no_inhibit | 0.050 | 2.1103 | 9.4540 | 52.0000 | 0.0000 | 0 | NaN | -0.8909 | -0.4397 |
| r049j_20A_off0p050_a2_post_active_inhibit | A2_deferred_post_active_inhibit | 0.050 | 2.0977 | 0.4840 | 52.0000 | 1.9300 | 1 | 0.0700 | -3.3927 | -0.4363 |
| r049j_20A_off0p105_a0 | A0_no_inhibit | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0 | NaN | -0.8991 | -0.4344 |
| r049j_20A_off0p105_a2_post_active_inhibit | A2_deferred_post_active_inhibit | 0.105 | 1.9439 | 0.4290 | 0.0000 | 1.9300 | 1 | 0.0710 | -4.1602 | -0.4417 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 inhibit us | A2 skipped REQ | A2 first inhibit us | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | 2.0977 | 0.0126 | 0.0000 | 1.9300 | 1 | 0.0700 | -2.5018 | 0.0034 |
| 0.105 | 2.0936 | 1.9439 | 0.1496 | 0.0000 | 1.9300 | 1 | 0.0710 | -3.2610 | -0.0073 |

## Decision

```text
MODEL_REVISED
```

This decision applies only to this R049J post-active inhibit chunk.
