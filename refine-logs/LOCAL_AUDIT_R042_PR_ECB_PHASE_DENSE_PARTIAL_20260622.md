# Local Audit: R042 PR-ECB Phase-Dense Partial Validation

## Scope

R042 starts phase-dense PR-ECB calibration around the high-side remaining-on-time boundary. It uses only the derived model under `output/simulink_iek` through the copied R042 runner and does not modify or save any original `.slx` model.

## Files Added or Updated

- Added `output/iqcot_r042_pr_ecb_phase_dense_calibration.m`.
- Added `output/iqcot_r042_pr_ecb_phase_dense_postprocess.py`.
- Generated `output/iqcot_r042_pr_ecb_phase_dense_plan.csv` with 20 planned cases.
- Completed true-run chunks `rows001_004` for near0 and `rows006_009` for 5A.
- Generated `output/iqcot_r042_pr_ecb_phase_dense_results_combined.csv`, summary, report, and paper section.

## Numerical Checks

- near0 and 5A both show the phase-4 high-side boundary between `0.09 us` and `0.105 us`: remaining on-time is `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` at `0.105/0.125 us`.
- In 8 completed rows, nonzero `E_HS,rem` appears in 4 rows. `E_HS,rem` is about `7.885 uJ` at `0.05 us` and `1.961 uJ` at `0.09 us`.
- near0: `r_E(max corrected)` spans `0.952-0.983`; 5A spans `0.812-0.839`.
- charge+ESR remains the dominant max-bound for all completed near0/5A rows; corrected-energy is useful as a phase-state diagnostic but does not dominate the max-bound in these rows.

## Claim Boundary

R042 partial supports a discrete active-HS boundary feature near phase-4 turn-off, not a global additive correction law. Evidence remains derived-Simulink/offline post-processing only, not hardware/HIL validation.

## Next Work

Run the remaining high-value R042 chunks: 10A rows `11-14` and 20A rows `16-19`, then rerun `iqcot_r042_pr_ecb_phase_dense_postprocess.py`. Rows `5/10/15/20` at `0.20 us` are useful lower-priority post-turnoff references.

## Full-Matrix Update

R042 subsequently completed all remaining rows: 10A rows `11-14`, 20A rows `16-19`, and post-turnoff reference rows `5/10/15/20`. The final matrix is 20/20 successful derived-Simulink rows.

- The phase-4 boundary is consistent across near0/5A/10A/20A: `52 ns` remaining on-time at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` from `0.105 us` onward.
- `E_HS,rem` appears in 8/20 rows and decays from `7.885 uJ` to `1.961 uJ` before vanishing.
- Dominant bound is load-segmented: charge+ESR dominates near0/5A, while corrected-energy/raw energy dominates most 10A/20A rows.
- Final `r_E(max corrected)` ranges: near0 `0.895-0.983`, 5A `0.760-0.839`, 10A `0.619-0.705`, 20A `0.516-0.602`.

Next work should fit a segmented PR-ECB calibration surface from the completed R040/R041/R042 data, keeping hardware/HIL and global-optimality claims out of scope.
