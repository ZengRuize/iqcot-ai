# R049O PR-ECB Release-Timing Micro-Audit

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049o_release_timing_results_full.csv`

| case | ctrl | offset us | release us | peak mV | undershoot mV | one-shot us | eff inhibit us |
|---|---|---:|---:|---:|---:|---:|---:|
| r049o_20A_off0p050_a0 | A0_no_inhibit | 0.050 | 1.250 | 2.1103 | -0.8909 | NaN | 0.0000 |
| r049o_20A_off0p050_a2_rel1p250 | A2_release_1p250us | 0.050 | 1.250 | 2.1103 | -0.8909 | 1.3100 | 1.2400 |
| r049o_20A_off0p050_a2_rel1p450 | A2_release_1p450us | 0.050 | 1.450 | 2.1103 | -0.8909 | 1.5100 | 1.4400 |
| r049o_20A_off0p105_a0 | A0_no_inhibit | 0.105 | 1.250 | 2.0936 | -0.8991 | NaN | 0.0000 |
| r049o_20A_off0p105_a2_rel1p250 | A2_release_1p250us | 0.105 | 1.250 | 2.0936 | -0.8991 | 1.2950 | 1.2240 |
| r049o_20A_off0p105_a2_rel1p450 | A2_release_1p450us | 0.105 | 1.450 | 2.0936 | -0.8991 | 1.4950 | 1.4240 |
