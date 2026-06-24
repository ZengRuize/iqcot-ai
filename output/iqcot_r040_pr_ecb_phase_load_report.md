# R040 PR-ECB Phase/Load Calibration

## Scope

R040 extends R039 by changing the load-step phase offset and adding larger 40A->10A and 40A->near0 cut-load points. It still uses only the derived delayed-reference Simulink model and offline PR-ECB post-processing.

## Results

| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual | charge+ESR/actual | dominant |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| r040_10A_off0p000 | 10A | 0.000 | 5.378 | 6.779 | 4.196 | 0.678 | 1.281670 | 1.615391 | charge_esr |
| r040_10A_off0p250 | 10A | 0.250 | 5.872 | 5.733 | 3.169 | 0.587 | 1.853266 | 1.809413 | energy |
| r040_20A_off0p000 | 20A | 0.000 | 4.350 | 3.903 | 2.235 | 0.435 | 1.946138 | 1.746454 | energy |
| r040_20A_off0p125 | 20A | 0.125 | 5.649 | 3.822 | 2.134 | 0.565 | 2.646638 | 1.790942 | energy |
| r040_20A_off0p250 | 20A | 0.250 | 4.844 | 3.199 | 2.143 | 0.484 | 2.260370 | 1.492574 | energy |
| r040_20A_off0p375 | 20A | 0.375 | 4.085 | 3.438 | 2.244 | 0.409 | 1.820420 | 1.532092 | energy |
| r040_near0_off0p000 | near0 | 0.000 | 5.717 | 9.929 | 6.525 | 0.993 | 0.876247 | 1.521787 | charge_esr |
| r040_near0_off0p250 | near0 | 0.250 | 6.211 | 8.580 | 5.193 | 0.858 | 1.196180 | 1.652301 | charge_esr |

## Summary

- 10A: n=2, r_E 0.587237 to 0.677856, energy/actual mean 1.567468, charge+ESR/actual mean 1.712402
- 20A: n=4, r_E 0.408518 to 0.564885, energy/actual mean 2.168392, charge+ESR/actual mean 1.640516
- near0: n=2, r_E 0.857988 to 0.992944, energy/actual mean 1.036213, charge+ESR/actual mean 1.587044

## Interpretation

The complete 8-row R040 matrix shows that PR-ECB is phase-sensitive and load-magnitude-sensitive. The 20A phase-offset sweep changes r_E from about 0.409 to 0.565. The 10A rows raise r_E to about 0.587-0.678. The near0 rows are the closest to the 10 mV allowance, with r_E about 0.858-0.993 and charge+ESR dominant. Energy-only can under-estimate the actual peak in the near0 offset-0 case, so the max(energy, charge+ESR) rule should be kept and a remaining high-side on-time correction should be investigated before claiming a calibration law. These results are not hardware/HIL validation.
