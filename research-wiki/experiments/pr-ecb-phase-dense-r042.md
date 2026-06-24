# R042 PR-ECB Phase-Dense Boundary Validation

## Scope

R042 adds phase-dense derived-Simulink validation around the phase-4 high-side remaining-on-time boundary identified by R040/R041. The plan covers `near0`, `5A`, `10A`, and `20A` cut-load targets at offsets `0.05/0.09/0.105/0.125/0.20 us`.

## Current Status

- Plan generated: `output/iqcot_r042_pr_ecb_phase_dense_plan.csv` with 20 rows.
- Completed rows `1-4`: near0 at offsets `0.05/0.09/0.105/0.125 us`.
- Completed rows `6-9`: 5A at offsets `0.05/0.09/0.105/0.125 us`.
- Combined outputs: `output/iqcot_r042_pr_ecb_phase_dense_results_combined.csv`, `output/iqcot_r042_pr_ecb_phase_dense_summary.csv`, `output/iqcot_r042_pr_ecb_phase_dense_report.md`.

## Key Result

For both near0 and 5A, phase 4 has remaining high-side on-time at `0.05 us` and `0.09 us`, then none at `0.105 us` and `0.125 us`. This localizes the turn-off boundary between `0.09 us` and `0.105 us`.

The initial near0/5A rows showed `E_HS,rem` decaying from about `7.885 uJ` to `1.961 uJ` before vanishing, with charge+ESR remaining dominant for those large cut-load cases. The full matrix below refines that into a load-segmented conclusion.

## Claim Boundary

R042 is derived-Simulink evidence only. It is not hardware/HIL validation, not proof of global PR-ECB calibration, and not a replacement for PIS-IEK/r_hat/B_epsilon post-peak recovery logic.

## Full-Matrix Completion

R042 later completed all `20/20` rows, including 10A rows `11-14`, 20A rows `16-19`, and the `0.20 us` post-turnoff reference rows `5/10/15/20`.

Final summary: phase-4 remaining high-side on-time is `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` from `0.105 us` onward for all four load targets. charge+ESR dominates near0/5A, while corrected-energy/raw energy dominates most 10A/20A rows. This supports a segmented PR-ECB calibration surface rather than a universal additive correction.
