## R043 segmented PR-ECB calibration surface

R043 converts the R040/R041/R042 first-peak evidence into a segmented calibration surface. The recommended first-peak risk feature is selected by load-drop magnitude and active high-side remaining-on-time. For near0/5A-like large cut-loads, charge+ESR remains the dominant bound. For 10A-like transition cases, corrected-energy is used when a high-side phase is still active and raw energy otherwise. For 20A-like smaller cut-loads, energy/corrected-energy dominates, but with higher conservatism versus the derived-Simulink actual peak. The rule table reports r_E, observed bound/actual ratios, and an outward-rounded conservative ratio band for each segment.

This supports writing PR-ECB as a segmented supervisory risk feature rather than a single additive correction law. The evidence remains derived-Simulink/offline only and should not be described as hardware or HIL validation.
