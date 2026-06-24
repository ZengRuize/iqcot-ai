# LOCAL AUDIT R027 Priority Switching Complete

Date: 2026-06-20

## Scope

This audit covers the completed R027 priority table-in-loop switching replay for the four-phase digital IQCOT / PIS-IEK study. The replay uses only the derived Simulink model:

`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

No original `.slx` file was modified, and no `.slx` XML was edited directly.

## Execution Summary

The R027 priority matrix contains 48 cases. They were executed in four chunks:

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows007_018.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows019_030.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows031_048.csv`

Combined output:

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_context_summary_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_vs_dense_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md`
- `E:/Desktop/codex/output/figures/fig35_r027_priority_combined_regret.svg`

Coverage check:

- Priority rows: `48`
- Combined switching rows: `48`
- Successful rows: `48`
- Missing rows: `0`

## Main Result

The R026 offline calibrated risk proxy advantage did not survive the stress-selected R027 priority switching replay.

| policy | mean switching regret | max switching regret | zero-regret contexts |
|---|---:|---:|---:|
| dense-long table | 0.025 | 0.111 | 6 |
| posterior upper bound | 0.025 | 0.111 | 6 |
| near-opt band | 0.257 | 0.517 | 2 |
| calibrated risk proxy | 0.283 | 1.001 | 3 |
| fixed 40us | 0.971 | 3.177 | 0 |
| fixed 80us | 2.171 | 5.298 | 0 |

Proxy versus dense-long across 8 priority contexts:

- proxy better: `0`
- proxy tied: `4`
- proxy worse: `4`

## Interpretation

R027 supports the following:

- `r_hat(z,T_slew)` can be connected to a derived Simulink delayed-reference table-in-loop runner.
- The priority replay is a useful stress test for objective-sensitive, delay-aware `T_slew` scheduling.
- The current calibrated proxy needs re-calibration, especially for `10A/score_settle005`, where proxy selects `62us` but dense-long `50us` is more robust for `tau_AI=0/0.5/1us`, and near-opt `34us` wins at `tau_AI=2us`.

R027 does not support:

- calibrated proxy is switching-level superior to dense-long table;
- neural-network AI-in-loop has been validated;
- any hardware/HIL conclusion;
- any global optimum claim for `T_slew`.

## Checks Performed

- MATLAB Code Analyzer on `iqcot_r027_proxy_table_in_loop_validation.m`: one info-level table growth warning only.
- Python postprocess script compiled with `py_compile`.
- Row count and success count verified from combined CSV.
- Local high-risk claim scan performed over the brief, paper, evidence matrix, derivation package, validation design, R027 reports, and wiki query pack. Remaining hits are boundary/non-claim statements or offline plan table values.

## Documents Updated

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan_report.md`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_paper_section.md`
- `E:/Desktop/codex/research-wiki/experiments/proxy-table-in-loop-plan.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`

## Next Research Step

Use R027 to redesign `B_epsilon(z,r_hat,tau_AI)`. A conservative next experiment is an R028 re-calibration pass that penalizes the `10A/score_settle005` proxy choice of `62us`, preserves the near0A `30us` tie behavior, and then replays only the affected priority contexts before considering a full 315-row run.

