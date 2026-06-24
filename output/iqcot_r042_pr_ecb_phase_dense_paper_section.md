## R042 remaining high-side on-time correction

R042 extends R041 by adding phase-dense derived-Simulink rows around the high-side turn-off boundary. L and Cout are re-inferred from each completed result row, and E_HS,rem is applied only when the load step occurs while a phase remains high-side-on.

The useful comparison is not a single corrected max-bound number, but the transition from pre-turnoff rows with nonzero remaining on-time to post-turnoff rows where E_HS,rem vanishes. The safest wording is that E_HS,rem is a phase-state feature for segmented PR-ECB calibration, not a globally validated additive law.

R042 remains derived-Simulink/offline evidence only. It supports a supervisory first-peak risk feature, while PIS-IEK, r_hat, and B_epsilon continue to govern post-peak recovery and T_slew deployment.
