# LOCAL AUDIT R040 PR-ECB Phase/Load Calibration

## Scope

- Continued heartbeat automation iqcot from R039 to R040.
- Used mandatory power-electronics-simulink-design skill and its references.
- Only loaded output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx; no save_system call and no direct SLX XML editing.

## Generated Artifacts

- output/iqcot_r040_pr_ecb_phase_load_calibration.m
- output/iqcot_r040_pr_ecb_postprocess.py
- output/iqcot_r040_pr_ecb_phase_load_plan.csv
- output/iqcot_r040_pr_ecb_phase_load_results_rows001_005.csv
- output/iqcot_r040_pr_ecb_phase_load_results_rows006_008.csv
- output/iqcot_r040_pr_ecb_phase_load_results_combined.csv
- output/iqcot_r040_pr_ecb_phase_load_summary.csv
- output/iqcot_r040_pr_ecb_phase_load_report.md
- output/iqcot_r040_pr_ecb_phase_load_paper_section.md
- output/data/*_r040_pr_ecb_wave.csv, eight files

## Numerical Check

- Derived-Simulink true-run cases completed: 8/8.
- 20A phase offsets: 0, 0.125, 0.25, 0.375 us.
- 20A r_E range: 0.408518 to 0.564885.
- 20A energy bound range: 4.085182 to 5.648852 mV.
- 20A actual first peak range: 2.134350 to 2.244088 mV.
- 20A energy/actual mean: 2.168392; charge+ESR/actual mean: 1.640516.
- 10A r_E range: 0.587237 to 0.677856.
- near0 r_E range: 0.857988 to 0.992944.
- near0 charge+ESR is dominant; near0 offset-0 has energy/actual=0.876247, so energy-only can under-estimate actual peak.
- Interpretation: PR-ECB is phase-sensitive and load-magnitude-sensitive; R039 conservatism ratios are not constant, and max(energy, charge+ESR) should be retained.

## Verification

- MATLAB Code Analyzer: no issues for output/iqcot_r040_pr_ecb_phase_load_calibration.m.
- Dry-run generated 8-row R040 plan.
- Python postprocess completed and generated combined summary/report.
- Claim boundary preserved: derived Simulink and offline post-processing only, not hardware/HIL validation.

## Next

- R041 should test an explicit remaining high-side on-time correction E_HS,rem and compare it against energy-only, charge+ESR, and max-bound PR-ECB variants.
