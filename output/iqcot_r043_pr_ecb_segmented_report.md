# R043 Segmented PR-ECB Calibration Surface

## Scope

R043 merges the completed R040/R041/R042 derived-Simulink evidence and fits an offline segmented PR-ECB calibration surface. No new Simulink run is performed. The surface is expressed as a conservative rule table over load-drop magnitude, active high-side remaining-on-time, and dominant bound class.

## Rule Table

| segment | active HS | targets | bound | r_E range | bound/actual range | conservative band | claim boundary |
| --- | ---: | --- | --- | ---: | ---: | ---: | --- |
| high_drop_charge_esr | 0 | near0/5A | charge_esr | 0.759573-0.968493 | 1.624910-1.700835 | 1.60-1.75x | Use charge+ESR as dominant first-peak risk feature for near0/5A-like large cut-loads; E_HS,rem is diagnostic only. |
| high_drop_charge_esr | 1 | near0/5A | charge_esr | 0.831513-0.992944 | 1.521787-1.665469 | 1.50-1.70x | Use charge+ESR as dominant first-peak risk feature for near0/5A-like large cut-loads; E_HS,rem is diagnostic only. |
| low_drop_energy | 0 | 20A | energy | 0.408518-0.580464 | 1.820420-2.810398 | 1.80-2.85x | Use raw energy for post-turnoff 20A-like smaller cut-loads; note conservatism is high versus actual first peak. |
| low_drop_energy | 1 | 20A | corrected_energy | 0.583069-0.626290 | 2.802184-2.870394 | 2.80-2.90x | Use corrected energy for active-HS 20A-like smaller cut-loads; note high conservatism versus actual first peak. |
| mid_drop_transition | 0 | 10A | energy | 0.587237-0.683170 | 1.814881-1.853266 | 1.80-1.90x | Use raw energy for post-turnoff 10A-like transition rows; treat as transition band, not universal law. |
| mid_drop_transition | 1 | 10A | corrected_energy | 0.685773-0.728950 | 1.737153-1.792178 | 1.70-1.80x | Use corrected energy for active-HS 10A-like transition rows; treat as transition band, not universal law. |

## Interpretation

The merged dataset contains 28 rows, including 11 active-HS rows. The completed R042 matrix shows a consistent phase-4 boundary: remaining on-time is present before 0.105 us and absent from 0.105 us onward. R043 therefore treats E_HS,rem as a segmentation feature, not a universal additive term.

The conservative ratio band is the observed recommended-bound/actual range rounded outward to 0.05x. It is a paper-facing summary of this derived-model dataset, not a universal safety factor.

The load segmentation is stable enough for a paper-safe statement: near0/5A-like large cut-loads are charge+ESR dominated; 10A is a transition band where corrected-energy resolves active-HS rows; 20A-like smaller cut-loads are energy/corrected-energy dominated but conservative versus actual first peak.

Boundary: this is derived-Simulink and offline post-processing evidence only. It is not hardware/HIL validation and does not prove global PR-ECB calibration.
