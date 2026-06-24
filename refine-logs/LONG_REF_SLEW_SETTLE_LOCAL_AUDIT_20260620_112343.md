# Long Reference-Slew / Settling-Aware Local Audit

## Verdict

PASS for the objective-sensitive reference-slew claim; WARN for any fixed optimum claim.

The added long-slew simulations and settling-aware post-processing support the revised paper claim: reference slew is not merely a fixed best value, but an objective-dependent scheduling variable suitable for AI/PIS-IEK supervisory control.

## Files Audited

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_long_best_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_settle_penalty_best.csv`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`

## Static Check

MATLAB Code Analyzer:

- No correctness errors.
- One performance info remains: a table grows inside a loop. This does not affect the reported values.

## Quantitative Checks

| Claim | Evidence | Status |
|---|---|---|
| Long scan has 9 successful switching cases | `iqcot_dynamic_ref_slew_long_summary.csv`: 3 targets x 3 slew values | exact_match |
| Long-grid best for `20A` is `80 us` | `iqcot_dynamic_ref_slew_long_best_summary.csv` | exact_match |
| Long-grid best for `10A` is `80 us` | `iqcot_dynamic_ref_slew_long_best_summary.csv` | exact_match |
| Long-only best for near-0A is `120 us` but with long settling | `undershoot=9.892 mV`, `settle_time=71.408 us`, `score=16.835` | exact_match |
| Combined base-score best remains `80/80/60 us` | `iqcot_dynamic_ref_slew_settle_penalty_best.csv` | exact_match |
| Light settling penalty best is `30/50/60 us` | `score+0.05*t_s` columns | exact_match |
| Medium settling penalty best is `30/30/30 us` | `score+0.10*t_s` columns | exact_match |

## Scope Checks

| Risk | Handling | Status |
|---|---|---|
| Claiming one universal reference slew | Draft now says optimum depends on objective weighting | PASS |
| Claiming slower is always better | Draft notes settling-time penalty shifts best toward faster transitions | PASS |
| Treating open-loop sweep as AI-in-loop | Draft states this supports an AI action variable, not completed AI deployment | PASS |
| Treating current grid optimum as global | Draft and evidence matrix forbid global-optimum wording | PASS |

## Remaining Work

The next meaningful step is to implement a simple scheduler that selects `T_slew` from event-domain features such as cut-load severity and allowed settling penalty, then test that scheduler in the same Simulink copy. This would move from parameter sweep evidence to controller-policy evidence.

