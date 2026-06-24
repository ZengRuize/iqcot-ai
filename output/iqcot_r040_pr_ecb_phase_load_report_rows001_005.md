# R040 PR-ECB Phase/Load Calibration

Run label: rows001_005

- Results: E:\Desktop\codex\output\iqcot_r040_pr_ecb_phase_load_results_rows001_005.csv
- Wave snapshots: output/data/*_r040_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r040_20A_off0p000 | 20A | 0.000 | 4.350 | 3.903 | 2.235 | 0.435 | 1.946 |
| r040_20A_off0p125 | 20A | 0.125 | 5.649 | 3.822 | 2.134 | 0.565 | 2.647 |
| r040_20A_off0p250 | 20A | 0.250 | 4.844 | 3.199 | 2.143 | 0.484 | 2.260 |
| r040_20A_off0p375 | 20A | 0.375 | 4.085 | 3.438 | 2.244 | 0.409 | 1.820 |
| r040_10A_off0p000 | 10A | 0.000 | 5.378 | 6.779 | 4.196 | 0.678 | 1.282 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
