# R043 Segmented PR-ECB Calibration Surface

## Scope

R043 reuses the completed R040/R041/R042 derived-Simulink evidence and performs
offline post-processing only. It fits a segmented PR-ECB first-peak calibration
surface over load-drop magnitude, active high-side remaining-on-time, and the
dominant first-peak bound class.

## Artifacts

- `output/iqcot_r043_pr_ecb_segmented_calibration.py`
- `output/iqcot_r043_pr_ecb_segmented_rows.csv`
- `output/iqcot_r043_pr_ecb_segmented_rules.csv`
- `output/iqcot_r043_pr_ecb_segmented_report.md`
- `output/iqcot_r043_pr_ecb_segmented_paper_section.md`

## Rule Summary

| segment | active HS | target class | recommended bound | r_E range | bound/actual range | conservative band |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| high_drop_charge_esr | 0 | near0/5A | charge+ESR | 0.760-0.968 | 1.625-1.701 | 1.60-1.75x |
| high_drop_charge_esr | 1 | near0/5A | charge+ESR | 0.832-0.993 | 1.522-1.665 | 1.50-1.70x |
| mid_drop_transition | 0 | 10A | raw energy | 0.587-0.683 | 1.815-1.853 | 1.80-1.90x |
| mid_drop_transition | 1 | 10A | corrected energy | 0.686-0.729 | 1.737-1.792 | 1.70-1.80x |
| low_drop_energy | 0 | 20A | raw energy | 0.409-0.580 | 1.820-2.810 | 1.80-2.85x |
| low_drop_energy | 1 | 20A | corrected energy | 0.583-0.626 | 2.802-2.870 | 2.80-2.90x |

## Key Result

R043 supports writing PR-ECB as a segmented supervisory first-peak risk feature.
near0/5A-like large load drops are charge+ESR dominated. 10A-like rows form a
transition band where active-HS state selects corrected energy and post-turnoff
state selects raw energy. 20A-like smaller load drops are energy/corrected-energy
dominated, but the bound is more conservative versus the derived-Simulink actual
first peak.

`E_HS,rem` should be used as an active-HS segmentation feature. The current data
do not support a global additive remaining-on-time correction law.

## Claim Boundary

This is derived-Simulink/offline post-processing evidence only. It is not
hardware validation, HIL validation, global PR-ECB calibration, or proof that
PIS-IEK precisely predicts the large-signal first peak. AI remains a supervisory
parameter-scheduling layer and does not replace the IQCOT inner loop.
