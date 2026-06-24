# R041 PR-ECB Remaining High-Side On-Time Correction

## Scope

R041 reuses the completed 8-row R040 derived-Simulink matrix and does not rerun or modify any .slx model. It tests an offline remaining high-side on-time correction, E_HS,rem, for rows where a phase is still high-side-on at the load-step instant. The correction estimates the additional inductor energy accumulated during the unavoidable remaining on-time and compares energy-only, charge+ESR, original max-bound, corrected-energy, and corrected max-bound variants.

## Inferred Physical Parameters

- L inferred from R040 energy rows: mean 2.000e-07 H, range 2.000e-07 to 2.000e-07 H.
- Cout inferred from R040 energy rows: mean 7.260000e-03 F, range 7.260000e-03 to 7.260000e-03 F.
- Vin assumption for residual high-side slope: 12.0 V.

## Results

| case | target | offset us | active HS rem | E_HS,rem uJ | energy mV | energy+corr mV | charge+ESR mV | max corr mV | actual mV | max corr/actual |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| r040_10A_off0p000 | 10A | 0.000 | 4 | 13.957 | 5.378 | 7.290 | 6.779 | 7.290 | 4.196 | 1.737 |
| r040_10A_off0p250 | 10A | 0.250 | - | 0.000 | 5.872 | 5.872 | 5.733 | 5.872 | 3.169 | 1.853 |
| r040_20A_off0p000 | 20A | 0.000 | 4 | 13.957 | 4.350 | 6.263 | 3.903 | 6.263 | 2.235 | 2.802 |
| r040_20A_off0p125 | 20A | 0.125 | - | 0.000 | 5.649 | 5.649 | 3.822 | 5.649 | 2.134 | 2.647 |
| r040_20A_off0p250 | 20A | 0.250 | - | 0.000 | 4.844 | 4.844 | 3.199 | 4.844 | 2.143 | 2.260 |
| r040_20A_off0p375 | 20A | 0.375 | - | 0.000 | 4.085 | 4.085 | 3.438 | 4.085 | 2.244 | 1.820 |
| r040_near0_off0p000 | near0 | 0.000 | 4 | 13.957 | 5.717 | 7.628 | 9.929 | 9.929 | 6.525 | 1.522 |
| r040_near0_off0p250 | near0 | 0.250 | - | 0.000 | 6.211 | 6.211 | 8.580 | 8.580 | 5.193 | 1.652 |

## Summary

- 10A: n=2, active-HS rows=1, energy under-actual 0->0 after correction, r_E(max corrected) 0.587237 to 0.728950, max-corr/actual mean 1.795209
- 20A: n=4, active-HS rows=1, energy under-actual 0->0 after correction, r_E(max corrected) 0.408518 to 0.626290, max-corr/actual mean 2.382403
- near0: n=2, active-HS rows=1, energy under-actual 1->0 after correction, r_E(max corrected) 0.857988 to 0.992944, max-corr/actual mean 1.587044
- ALL: n=8, active-HS rows=3, energy under-actual 1->0 after correction, r_E(max corrected) 0.408518 to 0.992944, max-corr/actual mean 2.036765

## Interpretation

Only 3 of 8 rows have nonzero E_HS,rem; all are offset-0 cases where phase 4 remains high-side-on for about 102 ns. The correction removes the only energy-only under-estimation in R040: near0 offset-0 changes from energy/actual < 1 to corrected-energy/actual > 1. However, the original max(energy, charge+ESR) bound was already conservative for all eight rows because charge+ESR covered the near0 case. Adding E_HS,rem to the max-bound increases conservatism for the active-HS 20A and 10A rows, so R041 supports using E_HS,rem as a phase-state diagnostic or a segmented energy-bound term rather than claiming one global correction law.

Boundary: this is offline post-processing of derived-Simulink R040 rows. It is not hardware/HIL validation, does not prove global PR-ECB calibration, and does not replace PIS-IEK/r_hat/B_epsilon post-peak recovery logic.
