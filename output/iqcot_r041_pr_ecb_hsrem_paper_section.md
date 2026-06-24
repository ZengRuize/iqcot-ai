## R041 remaining high-side on-time correction

R041 tests whether the R040 phase/load-sensitive PR-ECB boundary should include a residual high-side on-time term. From the 8 completed R040 rows, L and Cout are re-inferred from the original energy equations as 0.2 uH and 7.26 mF, then E_HS,rem is applied only when the load step occurs while a phase is still high-side-on. This happens in three offset-0 rows, all with phase 4 carrying about 102 ns of remaining on-time.

The correction fixes the important near0 offset-0 diagnostic: energy-only was below the derived-Simulink actual first peak, but corrected-energy becomes conservative. At the same time, max(energy, charge+ESR) was already conservative in all eight R040 rows because charge+ESR covered the near0 case. A direct corrected max-bound therefore improves the energy-only submodel but increases conservatism for the 20A and 10A active-HS rows. The safest wording is that E_HS,rem is a phase-state feature for segmented PR-ECB calibration, not a globally validated additive law.

R041 remains derived-Simulink/offline evidence only. It supports a supervisory first-peak risk feature, while PIS-IEK, r_hat, and B_epsilon continue to govern post-peak recovery and T_slew deployment.
