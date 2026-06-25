# R049N PR-ECB Independent-Clock One-Shot Reentry Chunk

Run label: `full`

## Scope

- Model: R049N copy of R049L repair with independent upstream release clock.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2: release at `t_load_step + 1.685us` during inhibit; Ton truncation disabled.
- A0: same model, negative inhibit window; Ton truncation disabled.
- R049K-compatible operating parameters restored.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049n_independent_clock_reentry_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049n_independent_clock_reentry_comparison_full.csv`
- Wave: `output/data/*_r049n_independent_clock_reentry_wave.csv`

## Baseline quality gate

Baseline check: `PASS`.

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | release us | one-shot us | inhibit raw us | effective inhibit us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049n_20A_off0p050_a0 | A0_no_inhibit | 0.050 | 2.1103 | 9.4540 | 50.5000 | 1.6860 | NaN | 0.0000 | 0.0000 | -0.8909 | -0.4397 |
| r049n_20A_off0p050_a2_independent_clock | A2_independent_clock_reentry | 0.050 | 2.0977 | 0.4840 | 50.5000 | 1.6860 | 1.7500 | 1.6900 | 1.6800 | -0.9623 | -0.4300 |
| r049n_20A_off0p105_a0 | A0_no_inhibit | 0.105 | 2.0936 | 8.3890 | 0.0000 | 1.6850 | NaN | 0.0000 | 0.0000 | -0.8991 | -0.4344 |
| r049n_20A_off0p105_a2_independent_clock | A2_independent_clock_reentry | 0.105 | 2.0241 | 12.1210 | 0.0000 | 1.6850 | 1.7350 | 1.6900 | 1.6640 | -0.9294 | -0.4347 |

## Pair comparison

| offset us | peak improvement mV | A2-A0 undershoot mV | A2 one-shot us | A2 effective inhibit us |
|---:|---:|---:|---:|---:|
| 0.050 | 0.0126 | -0.0714 | 1.7500 | 1.6800 |
| 0.105 | 0.0694 | -0.0303 | 1.7350 | 1.6640 |

## Decision

```text
MODEL_REVISED
```

This decision applies only to the R049N independent-clock one-shot reentry chunk.
