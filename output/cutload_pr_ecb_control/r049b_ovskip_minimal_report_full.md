# R049B PR-ECB Minimal Over-Voltage Skip Chunk

Run label: `full`

## Scope and hypothesis

- Model version: GAE-IQCOT R047 + R048 wiring + R049A scaffold + R049B simple OV-skip derived copy.
- Hypothesis: a minimal over-voltage skip gate can inhibit new IQCOT requests after `Vout > Vo_ref + Vov_skip` without replacing the IQCOT inner loop.
- Expected failure mode: skip may be too late to affect the first peak when an active high-side pulse is already injecting energy, or may create secondary undershoot/reentry delay.
- Metrics: peak overshoot, first-peak time, inhibit duration, skipped request count, secondary undershoot, final error.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no Ton truncation claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049b_ovskip.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049b_ovskip_minimal_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049b_ovskip_minimal_comparison_full.csv`
- Wave snapshots: `output/data/*_r049b_ovskip_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | inhibit us | skipped REQ | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| r049b_near0_off0p050_a0 | A0_no_skip | 0.050 | 6.2586 | 1.4000 | 0.0000 | 0 | -8.2934 | -0.5396 |
| r049b_near0_off0p050_a1_ovskip | A1_ov_skip | 0.050 | 6.2586 | 1.4000 | 18.8800 | 19 | -8.2934 | -0.5803 |
| r049b_near0_off0p105_a0 | A0_no_skip | 0.105 | 5.9603 | 1.3450 | 0.0000 | 0 | -7.2482 | -0.5695 |
| r049b_near0_off0p105_a1_ovskip | A1_ov_skip | 0.105 | 5.9603 | 1.3450 | 19.8160 | 20 | -7.2482 | -0.5502 |

## A1 versus A0 comparison

| offset us | A0 peak mV | A1 peak mV | improvement mV | A1 inhibit us | A1 skipped REQ | A1-A0 undershoot mV |
|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 6.2586 | 6.2586 | 0.0000 | 18.8800 | 19 | 0.0000 |
| 0.105 | 5.9603 | 5.9603 | 0.0000 | 19.8160 | 20 | 0.0000 |

## Decision

```text
CLAIM_DOWNGRADED
```

This decision applies only to this minimal chunk and should not be expanded into a full A-matrix claim.
