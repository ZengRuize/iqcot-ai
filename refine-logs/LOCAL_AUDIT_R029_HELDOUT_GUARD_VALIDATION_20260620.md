# Local Audit: R029 Held-Out Guard Validation

## Scope

继续推进四相数字 IQCOT / PIS-IEK 小信号模型研究。R029 对 R028 的 guarded proxy candidate 做 held-out 派生 Simulink 验证，重点检查 `10A/score_settle005` 的短斜率 delay guard 和 near0A 零延迟 guard 是否过拟合。

## Compliance

- 已读取 `E:/Desktop/codex/AGENTS.md`。
- 已读取 `C:/Users/zengruize/.agents/skills/power-electronics-simulink-design/SKILL.md`。
- 已读取 `references/simulink-design-rules.md` 与 `references/cot-optimization.md`。
- 未修改原始 `.slx`，未编辑 `.slx` XML。
- 仿真仅使用派生模型 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`。

## Generated / Updated Artifacts

- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_plan.py`
- `E:/Desktop/codex/output/iqcot_r029_guarded_heldout_plan.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_validation.m`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_combined_report.md`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_paper_section.md`
- `E:/Desktop/codex/output/figures/fig38_r029_heldout_guard_combined.svg`
- `E:/Desktop/codex/research-wiki/experiments/heldout-guard-validation.md`

## Simulation Coverage

Executed `21/21` derived Simulink held-out cases successfully:

- `10A / score_settle005`: `tau_AI=1.5/2.5/3us`, `T_slew=34/40/50/62us`.
- `near0A / score_settle010`: `tau_AI=0/0.25/0.5us`, `T_slew=30/35/38us`.

## Main Results

| context | best result | interpretation |
|---|---|---|
| `10A / score_settle005 / tau=1.5us` | `40us` | `34us` guard should not be extended below `2us` |
| `10A / score_settle005 / tau=2.5us` | `34us` | supports the R028 short-slew delay guard |
| `10A / score_settle005 / tau=3us` | `34us` | supports the R028 short-slew delay guard |
| `near0A / score_settle010 / tau=0us` | `38us` | fixed `35us` guard is too narrow |
| `near0A / score_settle010 / tau=0.25us` | `38us` | local band should include `38us` |
| `near0A / score_settle010 / tau=0.5us` | `30us` | dense/proxy action returns as best once delay is present |

Policy-family summary:

- `guarded_candidate`: mean switching regret `0.041`, max `0.124`.
- `dense_anchor`: mean switching regret `0.242`, max `0.661`.
- `old_proxy_failure_probe`: mean switching regret `0.806`, max `1.236`.

These family means are not full-policy deployment scores because each family appears in different held-out subsets.

## Verification

- Python compile passed for:
  - `iqcot_r029_heldout_guard_plan.py`
  - `iqcot_r029_heldout_guard_postprocess.py`
- MATLAB Code Analyzer on `iqcot_r029_heldout_guard_validation.m` reports only two info-level table-growth notes.
- R029 dry-run succeeded with `21 x 16` MATLAB plan rows.
- R029 switching runs completed in three chunks:
  - rows `001-006`
  - rows `007-012`
  - rows `013-021`
- Postprocess recomputed full-context regrets over all chunks.

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

## Boundary Statements

- R029 is derived Simulink evidence, not hardware/HIL validation.
- AI remains a supervisory parameter scheduler and does not replace the IQCOT inner loop.
- R029 does not prove a global `T_slew` optimum.
- R029 supports a refined R030 band policy, not a final hardware-safe controller.
