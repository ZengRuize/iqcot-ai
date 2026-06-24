# R042 PR-ECB Remaining High-Side On-Time Correction

## Scope

R042 post-processes the currently completed phase-dense derived-Simulink rows around the high-side remaining-on-time boundary. It does not modify or save any .slx model. It estimates E_HS,rem for rows where a phase is still high-side-on at the load-step instant, then compares energy-only, charge+ESR, raw max-bound, corrected-energy, and corrected max-bound variants.

## Inferred Physical Parameters

- L inferred from R042 energy rows: mean 2.000e-07 H, range 2.000e-07 to 2.000e-07 H.
- Cout inferred from R042 energy rows: mean 7.260000e-03 F, range 7.260000e-03 to 7.260000e-03 F.
- Vin assumption for residual high-side slope: 12.0 V.

## Results

| case | target | offset us | active HS rem | E_HS,rem uJ | energy mV | energy+corr mV | charge+ESR mV | max corr mV | actual mV | max corr/actual |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| r042_10A_off0p050 | 10A | 0.050 | 4 | 7.885 | 5.969 | 7.048 | 6.736 | 7.048 | 3.991 | 1.766 |
| r042_10A_off0p090 | 10A | 0.090 | 4 | 1.961 | 6.589 | 6.858 | 6.692 | 6.858 | 3.826 | 1.792 |
| r042_10A_off0p105 | 10A | 0.105 | - | 0.000 | 6.832 | 6.832 | 6.663 | 6.832 | 3.761 | 1.817 |
| r042_10A_off0p125 | 10A | 0.125 | - | 0.000 | 6.676 | 6.676 | 6.526 | 6.676 | 3.679 | 1.815 |
| r042_10A_off0p200 | 10A | 0.200 | - | 0.000 | 6.190 | 6.190 | 6.047 | 6.190 | 3.374 | 1.834 |
| r042_20A_off0p050 | 20A | 0.050 | 4 | 7.885 | 4.941 | 6.021 | 3.929 | 6.021 | 2.098 | 2.870 |
| r042_20A_off0p090 | 20A | 0.090 | 4 | 1.961 | 5.562 | 5.831 | 3.939 | 5.831 | 2.064 | 2.824 |
| r042_20A_off0p105 | 20A | 0.105 | - | 0.000 | 5.805 | 5.805 | 3.932 | 5.805 | 2.065 | 2.810 |
| r042_20A_off0p125 | 20A | 0.125 | - | 0.000 | 5.649 | 5.649 | 3.822 | 5.649 | 2.134 | 2.647 |
| r042_20A_off0p200 | 20A | 0.200 | - | 0.000 | 5.162 | 5.162 | 3.444 | 5.162 | 2.151 | 2.399 |
| r042_5A_off0p050 | 5A | 0.050 | 4 | 7.885 | 6.225 | 7.305 | 8.386 | 8.386 | 5.184 | 1.618 |
| r042_5A_off0p090 | 5A | 0.090 | 4 | 1.961 | 6.846 | 7.114 | 8.315 | 8.315 | 4.993 | 1.665 |
| r042_5A_off0p105 | 5A | 0.105 | - | 0.000 | 7.088 | 7.088 | 8.275 | 8.275 | 4.916 | 1.683 |
| r042_5A_off0p125 | 5A | 0.125 | - | 0.000 | 6.933 | 6.933 | 8.125 | 8.125 | 4.820 | 1.686 |
| r042_5A_off0p200 | 5A | 0.200 | - | 0.000 | 6.446 | 6.446 | 7.596 | 7.596 | 4.466 | 1.701 |
| r042_near0_off0p050 | near0 | 0.050 | 4 | 7.885 | 6.308 | 7.387 | 9.826 | 9.826 | 6.259 | 1.570 |
| r042_near0_off0p090 | near0 | 0.090 | 4 | 1.961 | 6.928 | 7.196 | 9.733 | 9.733 | 6.046 | 1.610 |
| r042_near0_off0p105 | near0 | 0.105 | - | 0.000 | 7.170 | 7.170 | 9.685 | 9.685 | 5.960 | 1.625 |
| r042_near0_off0p125 | near0 | 0.125 | - | 0.000 | 7.015 | 7.015 | 9.524 | 9.524 | 5.854 | 1.627 |
| r042_near0_off0p200 | near0 | 0.200 | - | 0.000 | 6.528 | 6.528 | 8.955 | 8.955 | 5.459 | 1.640 |

## Summary

- 10A: n=5, active-HS rows=2, energy under-actual 0->0 after correction, r_E(max corrected) 0.618954 to 0.704813, max-corr/actual mean 1.804811
- 20A: n=5, active-HS rows=2, energy under-actual 0->0 after correction, r_E(max corrected) 0.516182 to 0.602129, max-corr/actual mean 2.710228
- 5A: n=5, active-HS rows=2, energy under-actual 0->0 after correction, r_E(max corrected) 0.759573 to 0.838608, max-corr/actual mean 1.670559
- near0: n=5, active-HS rows=2, energy under-actual 0->0 after correction, r_E(max corrected) 0.895462 to 0.982597, max-corr/actual mean 1.614425
- ALL: n=20, active-HS rows=8, energy under-actual 0->0 after correction, r_E(max corrected) 0.516182 to 0.982597, max-corr/actual mean 1.950006

## Interpretation

Nonzero E_HS,rem appears in 8 of 20 completed rows. In the completed R042 matrix, phase-4 remaining on-time follows the same boundary for near0/5A/10A/20A: 52 ns at 0.05 us, 12 ns at 0.09 us, and 0 ns from 0.105 us onward. charge+ESR remains the dominant max-bound for near0 and 5A, while corrected-energy/raw energy dominates most 10A and 20A rows. This supports a segmented PR-ECB calibration feature, not a global additive correction law.

Boundary: this is offline post-processing of derived-Simulink R042 rows. It is not hardware/HIL validation, does not prove global PR-ECB calibration, and does not replace PIS-IEK/r_hat/B_epsilon post-peak recovery logic.
