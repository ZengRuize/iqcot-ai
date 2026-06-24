# R042 PR-ECB Phase-Dense Calibration

Run label: rows011_014

- Results: E:\Desktop\codex\output\iqcot_r042_pr_ecb_phase_dense_results_rows011_014.csv
- Wave snapshots: output/data/*_r042_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r042_10A_off0p050 | 10A | 0.050 | 5.969 | 6.736 | 3.991 | 0.674 | 1.496 |
| r042_10A_off0p090 | 10A | 0.090 | 6.589 | 6.692 | 3.826 | 0.669 | 1.722 |
| r042_10A_off0p105 | 10A | 0.105 | 6.832 | 6.663 | 3.761 | 0.683 | 1.817 |
| r042_10A_off0p125 | 10A | 0.125 | 6.676 | 6.526 | 3.679 | 0.668 | 1.815 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
