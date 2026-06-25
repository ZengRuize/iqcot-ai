# R049L Repair PR-ECB Phase-Boundary Controlled-Reentry Chunk

Run label: `full`

## Scope

- Model: R049L repair copy of R049I with phase-boundary one-shot reentry gate.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2: qh1-rising-edge one-shot reentry proxy; Ton truncation disabled.
- A0: same model, negative inhibit window; Ton truncation disabled.
- R049K-compatible operating parameters restored.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049l_repair_controlled_reentry_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049l_repair_controlled_reentry_comparison_full.csv`
- Wave: `output/data/*_r049l_repair_controlled_reentry_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | inhibit_raw us | eff_inhibit us | skipped REQ | first inhibit us | one_shot us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049l_repair_20A_off0p050_a0 | A0_no_inhibit | 0.050 | 2.1103 | 9.4540 | 50.5000 | 0.0000 | 0.0000 | 0 | NaN | NaN | -0.8909 | -0.4397 |
| r049l_repair_20A_off0p050_a2_one_shot | A2_one_shot_reentry | 0.050 | 2.0977 | 0.4840 | 50.5000 | 1.6900 | 1.6900 | 1 | 0.0700 | NaN | -1.0414 | -0.4422 |
| r049l_repair_20A_off0p105_a0 | A0_no_inhibit | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0.0000 | 0 | NaN | NaN | -0.8991 | -0.4344 |
| r049l_repair_20A_off0p105_a2_one_shot | A2_one_shot_reentry | 0.105 | 2.0316 | 12.1150 | 0.0000 | 1.6900 | 1.6900 | 1 | 0.0710 | NaN | -0.8444 | -0.4306 |

## Decision

```text
IMPLEMENTATION_ISSUE
```

This decision applies only to this R049L repair phase-boundary controlled-reentry chunk.

The A0 baseline now matches the R049K-compatible operating point, but the
intended phase-boundary one-shot release did not fire in either A2 row
(`one_shot_edge_count = 0`, `one_shot_time_us = NaN`).  Using `qh1` rising as
the release trigger creates a circular dependency: the request-path gate blocks
the scheduler pulse that would generate the `qh1` edge.  Therefore the A2 rows
effectively reproduce the fixed `0.070-1.760 us` inhibit-window behavior rather
than a true explicit controlled-reentry state machine.
