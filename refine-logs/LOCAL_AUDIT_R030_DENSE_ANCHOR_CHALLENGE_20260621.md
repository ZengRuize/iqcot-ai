# LOCAL AUDIT: R030 Dense-Anchor Challenge

Date: 2026-06-21

## Scope

This audit covers the R030 dense/proxy paired challenge post-processing and the
associated document updates.  No original `.slx` file was modified.  The source
simulation outputs were the three derived-Simulink chunks:

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows001_010.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows011_020.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows021_030.csv`

## Checks Performed

- Compiled `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_postprocess.py` with Python `py_compile`.
- Recomputed objective-specific scores from `base_score`, `score_settle005`, and `score_settle010`; maximum delta versus `selected_objective_score` was below `1e-8`.
- Confirmed all `30` challenge rows succeeded.
- Confirmed `15` complete dense/proxy paired contexts and `3` motif summaries.
- Confirmed policy-level values:
  - dense-anchor mean switching regret: `0.185799`
  - proxy mean switching regret: `0.574205`
  - dense-anchor best contexts: `8`
  - proxy best contexts: `7`
- Confirmed motif-level negative calibration:
  - `10A / score_settle010`: near tie, mean proxy-minus-dense score `0.009`
  - `20A / base`: unstable ranking, mean proxy-minus-dense score `0.082`
  - `20A / score_settle005`: proxy negative sample, mean proxy-minus-dense score `1.073`

## Updated Artifacts

- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_motif_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_report.md`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_paper_section.md`
- `E:/Desktop/codex/output/figures/fig40_r030_dense_anchor_challenge.svg`
- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/experiments/refined-band-policy.md`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`

## Claim Boundary

The new result does not prove a global optimum for `T_slew`, does not prove
dense-anchor is universally optimal, and does not validate neural-network
AI-in-loop or hardware behavior.  It supports a narrower conclusion: the current
offline proxy is useful for candidate generation, but it should not override
dense-anchor outside locally validated bands.  The `20A / score_settle005` and
`66us` case family should be used as a negative sample for tightening
`B_epsilon^sw` or training a short-horizon risk predictor.
