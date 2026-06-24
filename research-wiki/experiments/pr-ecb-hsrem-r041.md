# R041 PR-ECB Remaining High-Side On-Time Correction

## Scope

R041 reuses the completed R040 8-row derived-Simulink phase/load matrix and
does not rerun or modify any `.slx` model. It adds an offline
`E_HS,rem` correction for rows where a phase remains high-side-on at the
load-step instant.

## Artifacts

- `output/iqcot_r041_pr_ecb_hsrem_correction.py`
- `output/iqcot_r041_pr_ecb_hsrem_results.csv`
- `output/iqcot_r041_pr_ecb_hsrem_summary.csv`
- `output/iqcot_r041_pr_ecb_hsrem_report.md`
- `output/iqcot_r041_pr_ecb_hsrem_paper_section.md`

## Key Result

Nonzero `E_HS,rem` appears only in the three offset-0 rows, all with phase 4
carrying about `102 ns` remaining high-side on-time. The correction fixes the
near0 offset-0 energy-only under-estimation: energy/actual changes from
`0.876x` to corrected-energy/actual `1.169x`.

The original `max(energy, charge+ESR)` bound was already conservative across
all 8 rows because charge+ESR covered the near0 case. A direct corrected
max-bound therefore improves the energy-only submodel but increases
conservatism for active-HS 20A and 10A rows.

## Claim Boundary

R041 supports including remaining high-side on-time as a phase-state feature
for segmented PR-ECB calibration. It is not hardware/HIL validation, not a
global PR-ECB correction law, and not a replacement for PIS-IEK, `r_hat`, or
`B_epsilon` post-peak recovery logic.
