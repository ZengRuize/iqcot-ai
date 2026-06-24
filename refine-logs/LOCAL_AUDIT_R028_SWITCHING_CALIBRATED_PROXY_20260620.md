# Local Audit: R028 Switching-Calibrated Proxy

## Scope

继续推进四相数字 IQCOT / PIS-IEK 小信号模型研究。R028 基于已完成的 R027 `48` 行 priority derived-Simulink switching replay，重标定 `B_epsilon(z,r_hat,tau_AI)`，不修改原始 `.slx`，不编辑 `.slx` XML，不运行新 Simulink 工况。

## Skill / Rule Compliance

- 已重新读取 `E:/Desktop/codex/AGENTS.md`。
- 已读取 `C:/Users/zengruize/.agents/skills/power-electronics-simulink-design/SKILL.md`。
- 已读取 `references/simulink-design-rules.md` 与 `references/cot-optimization.md`。
- 未修改任何原始 `.slx`。
- 本轮只做 R027 结果后处理、文档更新和一致性审查。

## Generated Artifacts

- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_eval_priority.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv`
- `E:/Desktop/codex/output/iqcot_r028_context_failure_analysis.csv`
- `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_report.md`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_paper_section.md`
- `E:/Desktop/codex/output/figures/fig36_r028_switching_calibrated_proxy.svg`
- `E:/Desktop/codex/research-wiki/experiments/switching-calibrated-proxy.md`

## Main Numerical Results

Priority switching replay over the R027 stress contexts:

| policy | n | mean switching regret | max switching regret | interpretation |
|---|---:|---:|---:|---|
| `r028_switching_guarded_proxy` | 8 | `0.000` | `0.000` | stress-fitted candidate; requires held-out validation |
| `discrete_dense_long_table` | 8 | `0.025` | `0.111` | strong deployable baseline |
| `r028_dense_anchor_proxy` | 8 | `0.025` | `0.111` | conservative deployable projection; ties dense-long |
| `calibrated_risk_proxy_projection` | 8 | `0.283` | `1.001` | old R026 proxy; failed in 10A settling-aware stress contexts |

Offline R026-grid consistency replay:

- `r028_dense_anchor_proxy`: mean offline regret `0.099`.
- `near_opt_band_clipping`: mean offline regret `0.101`.
- `r028_switching_guarded_proxy`: mean offline regret `0.106`.
- old calibrated proxy: mean offline regret `0.119`.
- dense-long table: mean offline regret `0.163`.

## Interpretation

R028 fixes the R027-identified `10A/score_settle005` failure where the old proxy selected `62us`.  The conservative dense-anchor projection maps this failure back to the dense-long `50us` action and ties the dense-long baseline on the priority switching replay.

The guarded rule adds two pressure-fitted actions:

- `10A/score_settle005/tau_AI>=2us -> 34us`
- `near0A/score_settle010/tau_AI=0 -> 35us`

Because these guards are calibrated from the same priority stress contexts, the `0.000` regret result is not independent generalization evidence.  It should be treated as a R029 held-out validation candidate.

## Documentation Updated

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`

## Verification Commands

- `python -m py_compile E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`
- `python E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`
- File existence check for all R028 outputs.
- Text scan over core documents for over-claim phrases and key numbers.

All checks completed.  The first attempt with the system `python` lacked `pandas`; the bundled Codex Python runtime was then used successfully.

## Boundary Statements Preserved

- AI remains a supervisory parameter scheduler and does not replace the IQCOT inner loop.
- R028 does not prove a global optimum for `T_slew`.
- R028 does not prove hardware/HIL performance.
- R028 does not prove neural-network AI-in-loop superiority.
- R028 guarded candidate is fitted from R027 priority stress contexts and requires held-out derived Simulink validation.
