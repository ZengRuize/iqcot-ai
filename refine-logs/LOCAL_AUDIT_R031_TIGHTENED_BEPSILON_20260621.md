# Local Audit R031 Tightened B_epsilon^sw

## Scope

This audit covers the R031 tightened `B_epsilon^sw` / short-horizon risk predictor prototype and its documentation integration. R031 is an offline post-processing step based on the completed R030 dense-anchor challenge. It does not run or edit any `.slx` model and does not directly edit `.slx` XML.

## Files Checked

- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_sw.py`
- `E:/Desktop/codex/output/iqcot_r031_pair_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_rules.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_report.md`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_paper_section.md`
- `E:/Desktop/codex/output/figures/fig41_r031_tightened_bepsilon.svg`

## Mechanical Checks

- `python -m py_compile E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_sw.py`: passed.
- MATLAB Code Analyzer:
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation.m`: no issues.
  - `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`: one pre-existing informational warning about table growth in loop.
- CSV row counts:
  - `iqcot_r031_pair_risk_features.csv`: `15`
  - `iqcot_r031_tightened_bepsilon_policy_eval.csv`: `75`
  - `iqcot_r031_tightened_bepsilon_policy_summary.csv`: `5`
  - `iqcot_r031_tightened_bepsilon_rules.csv`: `3`
  - `iqcot_r031_minimal_validation_plan.csv`: `22`
- Figure exists:
  - `E:/Desktop/codex/output/figures/fig41_r031_tightened_bepsilon.svg`, size `4093` bytes.
- R031 dry-run executed:
  - MATLAB command: `addpath('E:/Desktop/codex/output'); rows = iqcot_r031_minimal_validation(false);`
  - Output plan: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv`
  - Dry-run report: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_dryrun_r031_minimal.md`
  - Loaded rows: `22`
- R031 derived-Simulink chunks executed:
  - `iqcot_r031_minimal_validation(true, 8, 1)`: `8/8` successful.
  - `iqcot_r031_minimal_validation(true, 8, 9)`: `8/8` successful.
  - `iqcot_r031_minimal_validation(true, 6, 17)`: `6/6` successful.
- R031 post-processing executed with bundled Python:
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation_postprocess.py`
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation_results_combined.csv`
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation_family_summary.csv`
  - `E:/Desktop/codex/output/iqcot_r031_minimal_validation_report.md`
  - `E:/Desktop/codex/output/figures/fig42_r031_minimal_validation.svg`

## Key Numerical Consistency

`iqcot_r031_tightened_bepsilon_policy_summary.csv` reports:

| Policy | Mean regret | Max regret | Proxy selected | Unsafe proxy selected |
|---|---:|---:|---:|---:|
| `r031_pair_oracle_upper_bound` | `0.000` | `0.000` | `7` | `1` |
| `r031_tightened_sw_projection` | `0.132241` | `1.688141` | `3` | `0` |
| `dense_anchor_baseline` | `0.185799` | `1.688141` | `0` | `0` |
| `r031_small_delta_only` | `0.188899` | `1.688141` | `5` | `1` |
| `direct_proxy_override` | `0.574205` | `2.792952` | `15` | `5` |

Validation-plan grouping:

- `10A / score_settle010`: `4` rows.
- `20A / base`: `6` rows.
- `20A / score_settle005`: `12` rows.

Dry-run schema spot check:

| Case | Target | Objective | T_slew us | tau_AI us | delay events |
|---|---|---|---:|---:|---:|
| `R031_0001` | `10A` | `score_settle010` | `31` | `1` | `2` |
| `R031_0002` | `10A` | `score_settle010` | `33` | `1` | `2` |
| `R031_0003` | `10A` | `score_settle010` | `31` | `5` | `10` |
| `R031_0004` | `10A` | `score_settle010` | `33` | `5` | `10` |
| `R031_0005` | `20A` | `base` | `82` | `0.5` | `1` |

Held-out context summary:

| Context | Best family | Best slew | Interpretation |
|---|---|---:|---|
| `10A / score_settle010 / tau=1us` | dense | `30us` | `31/33us` worse than dense |
| `10A / score_settle010 / tau=5us` | R031 intermediate | `33us` | supports delay-aware near-tie band |
| `20A / base / tau=0.5us` | dense | `80us` | `82us` is best intermediate but not better than dense |
| `20A / base / tau=2us` | dense | `80us` | `84us` is best intermediate but not better than dense |
| `20A / base / tau=5us` | dense | `80us` | `84us` near-ties dense but does not justify `86us` override |
| `20A / score_settle005 / tau=0.5us` | R031 intermediate | `50us` | useful middle band |
| `20A / score_settle005 / tau=1us` | R031 intermediate | `38us` | useful middle band |
| `20A / score_settle005 / tau=2us` | dense | `30us` | `50us` close but worse |
| `20A / score_settle005 / tau=5us` | dense | `30us` | `58us` best intermediate but worse than dense |

Aggregate held-out interpretation:

- R031 best intermediate beats dense baseline in `3/9` contexts.
- R031 best intermediate beats original R030 proxy in `8/9` contexts.
- Best-family counts are dense `6`, R031 intermediate `3`.
- Therefore R031 supports delay-aware local band with dense fallback, not proxy direct override.

## Documentation Updated

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/experiments/tightened-bepsilon-sw.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation.m`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_postprocess.py`
- `E:/Desktop/codex/research-wiki/experiments/tightened-bepsilon-sw.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/log.md`

## Claim Boundary Check

Local text search for R031 over-claims found only boundary-qualified statements. The integrated documents now state:

- R031 is a calibration candidate based on R030 challenge, not independent held-out validation.
- `0.132` mean regret is not a hardware or generalization proof.
- Pair oracle `0.000` is a non-deployable upper bound.
- AI/proxy remains a candidate score/risk generator; final `T_slew` must pass through `B_epsilon^sw`.
- R031 does not prove dense-anchor globally optimal and does not prove proxy useless.

## Remaining Risks

- `r031_tightened_sw_projection` uses observed winning subbands for `10A / score_settle010`; it may overfit R030 challenge.
- `20A / base` still needs intermediate `82/84us` delayed-reference checks before any proxy relaxation.
- `20A / score_settle005` still treats `66us` as blocked unless a short-horizon predictor can certify low skip/settling risk.
- R031 validation is still derived Simulink, not hardware/HIL.
- R031 intermediate candidates are not uniformly better than dense fallback.
- The `38-58us` band for `20A / score_settle005` is promising but remains delay-sensitive.

## Next Recommended Action

Upgrade R031 from hand-coded delay-aware bands to a short-horizon risk predictor design. Candidate input features should include `target_label`, `load_drop_A`, `objective_alpha_settle`, `tau_AI`, candidate `T_slew`, recent phase-spacing/skip state if available, and dense fallback identity. The output should remain a score/risk distribution passed through `B_epsilon^sw`, not a direct gate command or unconditional `T_slew` override.
