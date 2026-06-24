# Local Audit: R043 PR-ECB Segmented Calibration Surface

## Scope

R043 continues the PR-ECB large-signal branch from the completed R040/R041/R042
evidence. It performs offline CSV/Markdown post-processing only and does not run
new Simulink cases, modify original .slx files, or edit .slx XML.

## Files Added or Updated

- Updated `output/iqcot_r043_pr_ecb_segmented_calibration.py`.
- Regenerated `output/iqcot_r043_pr_ecb_segmented_rows.csv`.
- Regenerated `output/iqcot_r043_pr_ecb_segmented_rules.csv`.
- Regenerated `output/iqcot_r043_pr_ecb_segmented_report.md`.
- Regenerated `output/iqcot_r043_pr_ecb_segmented_paper_section.md`.
- Added `research-wiki/experiments/pr-ecb-segmented-r043.md`.
- Updated `research-wiki/query_pack.md`, `research-wiki/log.md`, and
  `output/iqcot_claims_evidence_matrix.md`.

## Numerical Checks

- Merged row-level dataset: 28 rows from R041-corrected R040 evidence and the
  full R042 phase-dense matrix.
- Active high-side rows: 11.
- Rule rows: 6, split by load-drop segment, active-HS state, and recommended
  bound class.
- Phase-state boundary inherited from R042: active high-side remaining on-time is
  present before 0.105 us and absent from 0.105 us onward.

## Rule Table Summary

| segment | active HS | target class | bound | r_E range | bound/actual range | conservative band |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| high_drop_charge_esr | 0 | near0/5A | charge+ESR | 0.760-0.968 | 1.625-1.701 | 1.60-1.75x |
| high_drop_charge_esr | 1 | near0/5A | charge+ESR | 0.832-0.993 | 1.522-1.665 | 1.50-1.70x |
| mid_drop_transition | 0 | 10A | raw energy | 0.587-0.683 | 1.815-1.853 | 1.80-1.90x |
| mid_drop_transition | 1 | 10A | corrected energy | 0.686-0.729 | 1.737-1.792 | 1.70-1.80x |
| low_drop_energy | 0 | 20A | raw energy | 0.409-0.580 | 1.820-2.810 | 1.80-2.85x |
| low_drop_energy | 1 | 20A | corrected energy | 0.583-0.626 | 2.802-2.870 | 2.80-2.90x |

## Claim Boundary

R043 supports a segmented PR-ECB first-peak risk feature:

- near0/5A-like large cut-loads: charge+ESR dominant.
- 10A-like transition rows: corrected energy for active-HS rows, raw energy
  after high-side turn-off.
- 20A-like smaller cut-loads: energy/corrected-energy dominant but conservative.

`E_HS,rem` is supported as an active-HS segmentation feature, not a globally
validated additive correction law. The evidence remains derived-Simulink/offline
post-processing only; it is not hardware/HIL validation, global PR-ECB
calibration, or proof that PIS-IEK precisely predicts the large-signal first
peak.
