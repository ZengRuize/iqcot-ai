# Local Audit: R041 PR-ECB Remaining High-Side On-Time Correction

## Scope

R041 continued from the completed R040 phase/load calibration. It did not run or modify any `.slx` model; it reprocessed `output/iqcot_r040_pr_ecb_phase_load_results_combined.csv` offline.

## Files Added or Updated

- Added `output/iqcot_r041_pr_ecb_hsrem_correction.py`.
- Generated `output/iqcot_r041_pr_ecb_hsrem_results.csv`.
- Generated `output/iqcot_r041_pr_ecb_hsrem_summary.csv`.
- Generated `output/iqcot_r041_pr_ecb_hsrem_report.md`.
- Generated `output/iqcot_r041_pr_ecb_hsrem_paper_section.md`.
- Added `research-wiki/experiments/pr-ecb-hsrem-r041.md`.
- Updated `research-wiki/query_pack.md`, `research-wiki/index.md`, `research-wiki/log.md`, and `output/iqcot_claims_evidence_matrix.md`.

## Numerical Checks

- Inferred `L=2.000e-07 H` and `Cout=7.260e-03 F` consistently from all 8 R040 rows.
- Nonzero `E_HS,rem` appears only in the three offset-0 rows with phase 4 high-side-on and `102 ns` remaining on-time.
- `r040_near0_off0p000` energy-only was under actual (`0.876x`); corrected-energy becomes conservative (`1.169x`).
- Original `max(energy, charge+ESR)` remained conservative for all 8 rows; corrected max-bound increases active-HS 20A/10A conservatism.

## Claim Boundary

R041 supports using remaining high-side on-time as a phase-state diagnostic or segmented energy-bound feature for PR-ECB calibration. It does not prove a global additive correction law, hardware/HIL safety, or replacement of PIS-IEK/r_hat/B_epsilon post-peak recovery logic.

## Next Work

R042 should run or design a phase-dense validation around high-side-on boundaries, especially offsets just before and after phase-4 turn-off, and add extra near0/5A/10A cut-load points to separate corrected-energy dominance from charge+ESR dominance.
