# LOCAL AUDIT R039 PR-ECB Large-Signal Boundary

## Scope

- Continued the previous thread after R038 by adding the large-signal PR-ECB branch requested by the user.
- Used the mandatory power-electronics-simulink-design skill and kept the original SLX untouched.
- Only loaded the derived model output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx; no save_system call and no direct SLX XML editing.

## Generated Artifacts

- output/iqcot_r039_pr_ecb_large_signal_probe.m
- output/iqcot_r039_pr_ecb_postprocess.py
- output/iqcot_r039_pr_ecb_large_signal_plan.csv
- output/iqcot_r039_pr_ecb_large_signal_results_rows001_001.csv
- output/iqcot_r039_pr_ecb_large_signal_results_rows002_005.csv
- output/iqcot_r039_pr_ecb_large_signal_results_combined.csv
- output/iqcot_r039_pr_ecb_large_signal_summary.csv
- output/iqcot_r039_pr_ecb_large_signal_report.md
- output/iqcot_r039_pr_ecb_large_signal_paper_section.md
- output/data/*_r039_pr_ecb_wave.csv, five files
- research-wiki/experiments/pr-ecb-large-signal-r039.md

## Numerical Check

- Derived-Simulink cases completed: 5/5.
- Load step: 40A -> 20A, score_settle005 context.
- Covered T_slew/tau_AI pairs: 46us/1.25us, 50us/1.5us, 54us/1.75us, 30us/2us, 48us/2us.
- Energy-bound estimate: 4.349633 mV.
- Charge+ESR estimate: 3.903338 mV.
- Actual derived-Simulink first peak: 2.235008 mV at about 0.534 us after load step.
- r_E with 10 mV allowance: 0.434963.
- First-peak values are invariant across the delayed T_slew cases, consistent with the peak occurring before tau_AI >= 1.25us reference action affects the plant.

## Verification

- MATLAB Code Analyzer: no issues for output/iqcot_r039_pr_ecb_large_signal_probe.m.
- Python compile: python -m py_compile output/iqcot_r039_pr_ecb_postprocess.py passed.
- Required R039 output files exist.
- R039 mentions were found in integrated paper, claims matrix, derivation package, AI supervisor design, query_pack, wiki index/log, and the new experiment page.
- Overclaim scan matched only boundary or Do-not-claim language; no positive claim of hardware validation, global optimum, or PR-ECB replacing post-peak PIS-IEK/r_hat logic was introduced.

## Claim Boundary

- Safe: R039 supports PR-ECB as a conservative first-peak risk feature and safety-bound generator.
- Safe: PR-ECB complements PIS-IEK by handling the first-peak interval before delayed AI action is active.
- Do not claim: hardware validation, HIL validation, global T_slew optimality, precise first-peak prediction by PIS-IEK, or replacement of r_hat/B_epsilon post-peak recovery logic.

## Next

- R040 should vary load-step phase and load-drop magnitude to calibrate PR-ECB conservatism.
- Prioritize t_load_step phase offsets relative to QH state, then 40A->10A and 40A->near0 load drops if runtime allows.
