# R040 PR-ECB Phase/Load Calibration

Run label: rows006_008

- Results: E:\Desktop\codex\output\iqcot_r040_pr_ecb_phase_load_results_rows006_008.csv
- Wave snapshots: output/data/*_r040_pr_ecb_wave.csv

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r040_10A_off0p250 | 10A | 0.250 | 5.872 | 5.733 | 3.169 | 0.587 | 1.853 |
| r040_near0_off0p000 | near0 | 0.000 | 5.717 | 9.929 | 6.525 | 0.993 | 0.876 |
| r040_near0_off0p250 | near0 | 0.250 | 6.211 | 8.580 | 5.193 | 0.858 | 1.196 |

Boundary: derived Simulink and offline post-processing only; not hardware/HIL validation.
