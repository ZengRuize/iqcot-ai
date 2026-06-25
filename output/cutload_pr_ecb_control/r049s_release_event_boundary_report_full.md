# R049S PR-ECB Release-Event Boundary Audit

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049s_release_event_boundary_results_full.csv`
- Ts_ctrl: `40.000 ns`

| case | ctrl | release us | one-shot us | predicted us | err ns | peak mV | undershoot mV | eff inhibit us |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| r049s_20A_off0p105_a0 | A0_no_inhibit | 1.615 | NaN | NaN | NaN | 2.0936 | -0.8991 | 0.0000 |
| r049s_20A_off0p105_a2_rel1p615 | A2_release_1p615us | 1.615 | 1.6550 | 1.6550 | 0.00 | 1.9739 | -0.8499 | 1.5840 |
| r049s_20A_off0p105_a2_rel1p616 | A2_release_1p616us | 1.616 | 1.6950 | 1.6950 | 0.00 | 2.0759 | -0.8396 | 1.6240 |
| r049s_20A_off0p105_a2_rel1p620 | A2_release_1p620us | 1.620 | 1.6950 | 1.6950 | 0.00 | 2.0759 | -0.8396 | 1.6240 |
| r049s_20A_off0p105_a2_rel1p625 | A2_release_1p625us | 1.625 | 1.6950 | 1.6950 | 0.00 | 2.0759 | -0.8396 | 1.6240 |
| r049s_20A_off0p105_a2_rel1p630 | A2_release_1p630us | 1.630 | 1.6950 | 1.6950 | 0.00 | 2.0759 | -0.8396 | 1.6240 |
