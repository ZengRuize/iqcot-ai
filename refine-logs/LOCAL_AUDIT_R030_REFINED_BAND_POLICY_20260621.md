# LOCAL AUDIT R030 refined-band policy

## Scope

本次审查覆盖 R030 refined-band policy 后处理、dense-anchor challenge 计划、文档同步和可执行入口。

## Files Created Or Updated

- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy.py`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_context_bands.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_switching_evidence.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_candidates.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_report.md`
- `E:/Desktop/codex/output/iqcot_r030_refined_band_paper_section.md`
- `E:/Desktop/codex/output/figures/fig39_r030_refined_band_policy.svg`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_validation.m`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/experiments/refined-band-policy.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`

## Numeric Checks

- R030 offline mean regret: `0.103523`.
- R028 guarded offline mean regret: `0.106276`.
- R028 dense-anchor offline mean regret: `0.099456`.
- Known guard-context R030 mean switching regret: `0.000000`.
- Known guard-context dense-anchor mean switching regret: `0.128364`.
- R030 challenge plan rows: `30`.
- Challenge groups: `10A/score_settle010` `10` rows; `20A/base` `10` rows; `20A/score_settle005` `10` rows.

## Verification Commands

- Python compile:
  - `python -m py_compile E:/Desktop/codex/output/iqcot_r030_refined_band_policy.py`
- MATLAB Code Analyzer:
  - `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_validation.m`: no issues.
  - `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`: one existing info-level dynamic table growth note.
- MATLAB dry run:
  - `iqcot_r030_dense_anchor_challenge_validation(false)`
  - Result: loaded `30` rows and wrote `iqcot_r027_proxy_table_in_loop_matlab_plan_r030_challenge.csv`.

## Claim Boundary

- R030 is post-processing plus validation design. It does not run new `.slx` cases.
- R030 does not modify original `.slx` and does not edit `.slx` XML.
- R030 does not prove hardware/HIL safety, neural-network AI-in-loop superiority, or global `T_slew` optimality.
- The `0.000` known guard-context regret is a consistency synthesis over R027/R029 local evidence, not independent generalization.
- The `30`-row dense/proxy challenge plan is a future experiment design, not a result.

## Next Work

Run the R030 dense-anchor challenge plan on the derived model if additional switching evidence is desired:

```matlab
iqcot_r030_dense_anchor_challenge_validation(true)
```

Chunked execution can use:

```matlab
iqcot_r030_dense_anchor_challenge_validation(true,10,1)
iqcot_r030_dense_anchor_challenge_validation(true,10,11)
iqcot_r030_dense_anchor_challenge_validation(true,10,21)
```

