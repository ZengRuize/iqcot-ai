# R042 PR-ECB Phase-Dense Calibration

Run label: rows016_019

- Results: E:\Desktop\codex\output\iqcot_r042_pr_ecb_phase_dense_results_rows016_019.csv
- Wave snapshots: output/data/*_r042_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r042_20A_off0p050 | 20A | 0.050 | 4.941 | 3.929 | 2.098 | 0.494 | 2.355 |
| r042_20A_off0p090 | 20A | 0.090 | 5.562 | 3.939 | 2.064 | 0.556 | 2.694 |
| r042_20A_off0p105 | 20A | 0.105 | 5.805 | 3.932 | 2.065 | 0.580 | 2.810 |
| r042_20A_off0p125 | 20A | 0.125 | 5.649 | 3.822 | 2.134 | 0.565 | 2.647 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
