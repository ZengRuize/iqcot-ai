# R039 PR-ECB Large-Signal First-Peak Boundary

## Status

- verdict: partial
- confidence: medium-low
- date: 2026-06-21

## Question

Can the large-signal first peak after a 40A->20A load drop be represented as a phase-resolved energy-charge boundary feature r_E, separated from the PIS-IEK post-peak recovery model?

## Evidence

- output/iqcot_r039_pr_ecb_large_signal_probe.m
- output/iqcot_r039_pr_ecb_postprocess.py
- output/iqcot_r039_pr_ecb_large_signal_results_combined.csv
- output/iqcot_r039_pr_ecb_large_signal_summary.csv
- output/iqcot_r039_pr_ecb_large_signal_report.md
- output/iqcot_r039_pr_ecb_large_signal_paper_section.md
- output/data/*_r039_pr_ecb_wave.csv

## Result

All five derived-Simulink delayed-reference cases succeeded. They cover 46/50/54us folded anchors and the tau_AI=2us 30/48us foldback near-tie pair. The first-peak state and result are invariant across these delayed T_slew cases because the first peak occurs around 0.534us after load step, before the AI reference action with tau_AI>=1.25us can affect the plant.

Summary:

- energy boundary: 4.350 mV
- charge+ESR boundary: 3.903 mV
- derived-Simulink first peak: 2.235 mV
- r_E with 10 mV allowance: 0.435

## Interpretation

PR-ECB should be treated as a conservative first-peak risk feature and safety-bound generator. PIS-IEK remains the normal/quasi-normal event recovery model for skip/reentry, phase spacing, settling, and T_slew deployment.

## Next

R040 should vary load-step phase, load-drop magnitude, and possibly t_load_step relative to QH state, then calibrate PR-ECB conservatism and determine whether r_E predicts first-peak risk across phase-resolved states.
