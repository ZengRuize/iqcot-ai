# R042 PR-ECB Phase-Dense Calibration

Run label: rows001_004

- Results: E:\Desktop\codex\output\iqcot_r042_pr_ecb_phase_dense_results_rows001_004.csv
- Wave snapshots: output/data/*_r042_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r042_near0_off0p050 | near0 | 0.050 | 6.308 | 9.826 | 6.259 | 0.983 | 1.008 |
| r042_near0_off0p090 | near0 | 0.090 | 6.928 | 9.733 | 6.046 | 0.973 | 1.146 |
| r042_near0_off0p105 | near0 | 0.105 | 7.170 | 9.685 | 5.960 | 0.968 | 1.203 |
| r042_near0_off0p125 | near0 | 0.125 | 7.015 | 9.524 | 5.854 | 0.952 | 1.198 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
