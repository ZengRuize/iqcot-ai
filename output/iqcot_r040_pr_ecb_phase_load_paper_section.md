## R040 PR-ECB phase/load calibration

R040 extends the R039 first-peak boundary probe by varying load-step phase offset and load-drop magnitude. All 8 derived-Simulink cases were executed. For 40A->20A, changing the load-step offset from 0 to 0.375us changes the energy-bound estimate from 4.085 to 5.649mV and r_E from 0.409 to 0.565, while the actual first peak stays in the narrower 2.134 to 2.244mV range. This supports the PR-ECB design choice: the first-peak risk feature should include phase-resolved inductor/gate state rather than only load-drop magnitude.

For 40A->10A, r_E spans 0.587-0.678 across the two phase offsets. For 40A->near0, r_E spans 0.858-0.993 and charge+ESR is dominant. The near0 offset-0 case is especially informative: energy-only is below the actual peak, while charge+ESR remains conservative. This means the R039 conservatism ratios are not constants; calibration should remain piecewise by load magnitude and phase state, and the remaining high-side on-time correction E_HS,rem should be tested before any stronger law is claimed.

Boundary: these are derived-Simulink and offline post-processing results only. PR-ECB remains a first-peak risk feature and safety-bound generator; it is not hardware validation and does not replace PIS-IEK/r_hat/B_epsilon post-peak recovery logic.
