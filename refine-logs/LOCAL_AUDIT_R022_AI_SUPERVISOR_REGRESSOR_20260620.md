# LOCAL AUDIT R022: AI Supervisor Regressor Baseline

Date: 2026-06-20

## Scope

R022 advances the four-phase digital IQCOT / PIS-IEK research from table-driven delayed-reference validation to an interpretable score-prediction supervisor baseline.  No original `.slx` file was modified.  No `.slx` XML was edited.  No new Simulink run was required; this audit covers post-processing of existing derived switching results.

## Inputs

- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results.csv`

## New Outputs

- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_baseline.py`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_dataset.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_context_labels.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_eval.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_summary.csv`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_report.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_paper_section.md`
- `E:/Desktop/codex/output/figures/fig29_ai_supervisor_regressor_regret.svg`
- `E:/Desktop/codex/research-wiki/experiments/ai-supervisor-regressor-baseline.md`

## Row Count Checks

- Candidate-score dataset: `180` rows.
- Context labels: `36` rows.
- Cross-validation eval rows: `504` rows.
- Summary rows: `14` rows.

These match the design:

```text
60 positive-delay switching cases
  x 3 objectives = 180 candidate-score rows

4 tau contexts x 3 target loads x 3 objectives
  = 36 supervised contexts

36 contexts x 7 models x 2 split families
  = 504 eval rows
```

## Main Results

- Leave-one-tau-out best model: `trained_objective_nearest_tau_table`, mean regret `0.304`.
- Zero-delay objective table leave-one-tau regret: `0.316`; the delay-aware margin is only `0.013`.
- Fixed `40 us` leave-one-tau regret: `1.131`; best model is about `73.2%` lower.
- Leave-one-target-out best model remains `zero_delay_objective_table`, mean regret `0.316`.
- Best score regressor under leave-one-target-out is `ridge_score_supervisor`, mean regret `0.620`; it is better than fixed slopes but not better than the strong zero-delay table.
- `11/36` contexts have exact oracle ties; `23/36` have first-second margin `<=0.25`, so regret is more meaningful than raw policy accuracy.

## Consistency Checks

- `python -m py_compile output/iqcot_ai_supervisor_regressor_baseline.py` passed.
- Output figure exists: `fig29_ai_supervisor_regressor_regret.svg`, length `3888` bytes.
- Local text search found strong phrases only inside explicit boundaries or forbidden-writing clauses:
  - no affirmative claim of global `T_slew` optimality;
  - no affirmative claim that AI replaces IQCOT inner loop;
  - no affirmative claim of hardware validation;
  - no affirmative claim that PIS-IEK precisely predicts large cut-load first peak;
  - no affirmative claim that neural-network AI-in-loop is already complete.

## Updated Documents

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`

## Boundary Statement

R022 supports this claim:

> A low-dimensional, interpretable supervisor can approximate delayed-reference policy ranking and is clearly better than fixed `40/80 us` slopes in the current data.

R022 does not support these claims:

- AI or a regressor is stably better than the strongest zero-delay objective table under all generalization splits.
- Continuous `T_slew` regression has been validated.
- Neural-network AI-in-loop, FPGA/HIL, or hardware validation is complete.
- PIS-IEK can precisely predict the first peak of a large cut-load transient.

## Next Work

The next meaningful experiment is not another discrete table-only comparison.  It should either expand the `T_slew` grid for continuous score regression or implement the learned supervisor in the derived Simulink reference channel with the same delay-buffer semantics, while keeping AI as a supervisory parameter scheduler only.
