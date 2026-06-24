# R042 PR-ECB Phase-Dense Calibration

Run label: rows006_009

- Results: E:\Desktop\codex\output\iqcot_r042_pr_ecb_phase_dense_results_rows006_009.csv
- Wave snapshots: output/data/*_r042_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r042_5A_off0p050 | 5A | 0.050 | 6.225 | 8.386 | 5.184 | 0.839 | 1.201 |
| r042_5A_off0p090 | 5A | 0.090 | 6.846 | 8.315 | 4.993 | 0.832 | 1.371 |
| r042_5A_off0p105 | 5A | 0.105 | 7.088 | 8.275 | 4.916 | 0.828 | 1.442 |
| r042_5A_off0p125 | 5A | 0.125 | 6.933 | 8.125 | 4.820 | 0.812 | 1.438 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
