# LOCAL AUDIT R027 Proxy Table-In-Loop

Date: 2026-06-20

## Scope

R027 converts the R026 deployable `r_hat(z,T_slew)` risk proxy into a derived Simulink table-in-loop validation matrix and MATLAB runner. The work does not edit original `.slx` files and does not directly edit `.slx` XML.

## Files Created

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.py`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_priority_plan.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_expected_summary.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_expected_detail.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan_report.md`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_paper_section.md`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_priority.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_switching_report_priority.md`
- `E:/Desktop/codex/output/figures/fig34_r027_proxy_table_in_loop_priority.png`
- `E:/Desktop/codex/research-wiki/experiments/proxy-table-in-loop-plan.md`

## Checks Performed

- Required power-electronics Simulink skill and references were read before model-related work.
- R027 plan generator was executed with bundled Python.
- MATLAB dry-run successfully loaded the priority plan and wrote `iqcot_r027_proxy_table_in_loop_matlab_plan_priority.csv`.
- MATLAB Code Analyzer was run on `iqcot_r027_proxy_table_in_loop_validation.m`; only one info-level table-growth warning was reported.
- A six-case derived-model switching smoke run was executed through `four_phase_iek_dynamic_load_refslew.slx`.
- CSV row counts were verified:
  - full plan: `315`
  - priority plan: `48`
  - smoke switching results: `6`
- Local claim scan was performed for high-risk phrases such as global optimum, hardware validation, AI replacement, and exact large cut-load first-peak prediction. Hits were boundary or non-claim statements.

## Smoke Switching Result

The smoke run covers only `10A / score_settle005 / tau_AI=0`:

| policy | T_slew us | selected objective | regret |
|---|---:|---:|---:|
| discrete_dense_long_table | 50 | 10.008 | 0.000 |
| posterior_mode_aware_projection | 50 | 10.008 | 0.000 |
| near_opt_band_clipping | 34 | 10.217 | 0.209 |
| fixed_40us_precommitted | 40 | 10.262 | 0.254 |
| calibrated_risk_proxy_projection | 62 | 10.363 | 0.355 |
| fixed_80us_precommitted | 80 | 10.539 | 0.531 |

This verifies the runner and delayed-reference interface, but it also shows a local negative case where calibrated proxy is weaker than dense-long table. The full R027 claim must therefore remain conditional until the remaining priority matrix is run.

## Documents Updated

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`

## Non-Claims

- R027 does not prove calibrated proxy is globally or locally always better than dense-long table.
- R027 does not complete neural-network AI-in-loop validation.
- R027 is not hardware or HIL validation.
- Posterior mode-aware projection remains an upper-bound comparator, not a deployable policy.
- `T_slew` is not claimed to have a global optimum.
- PIS-IEK is not claimed to exactly predict large cut-load first peak.

## Next Step

Run the remaining `42` rows of the R027 priority matrix. If calibrated proxy ordering does not hold, re-tune the `B_epsilon(z,r_hat,tau_AI)` safety projection before attempting a neural-network supervisor.

