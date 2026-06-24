# R049I PR-ECB Gentle Phase-Selective Ton-Trim Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049I copy of R049G with repaired `t_load_step` lower bound and inherited per-phase `early_window AND qh_i` guards.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2 gentle phase-selective Ton trim: `Tton_trunc_min=120ns`, `Tton_trunc_window=80ns`.
- A0 baseline: same model, negative time window disables truncation.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049i_gentle_tontrim_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049i_gentle_tontrim_comparison_full.csv`
- Wave snapshots: `output/data/*_r049i_gentle_tontrim_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | tr1 us | tr2 us | tr3 us | tr4 us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049i_20A_off0p050_a0 | A0_no_trunc | 0.050 | 2.1103 | 9.4540 | 52.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8909 | -0.4397 |
| r049i_20A_off0p050_a2_gentle_trim | A2_gentle_phase_selective_ton_trim | 0.050 | 2.3879 | 0.8980 | 2.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0040 | -0.8562 | -0.4351 |
| r049i_20A_off0p105_a0 | A0_no_trunc | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8991 | -0.4344 |
| r049i_20A_off0p105_a2_gentle_trim | A2_gentle_phase_selective_ton_trim | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8991 | -0.4344 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 tr1 us | A2 tr2 us | A2 tr3 us | A2 tr4 us | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | 2.3879 | -0.2776 | 50.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0040 | 0.0348 | 0.0046 |
| 0.105 | 2.0936 | 2.0936 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |

## Decision

```text
MODEL_REVISED
```

This decision applies only to this R049I gentle Ton-trim chunk.
