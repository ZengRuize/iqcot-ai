# Dense Reference-Slew Local Audit

## Verdict

PASS for the local dense reference-slew claim; WARN for global optimality.

The dense Simulink sweep proves that the previous `40 us` boundary result was not a final optimum within the broader `20-80 us` grid. It supports the claim that `Iph_ref` slew time is a meaningful low-dimensional scheduling variable for AI/PIS-IEK control. It does not support a global optimum claim.

## Files Checked

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`

## Static Check

MATLAB Code Analyzer result:

- No errors.
- No warnings affecting correctness.
- One info item remains: table variable size changes in a loop. This is a performance note and does not affect the results.

## Quantitative Reconciliation

| Claim | Evidence | Status |
|---|---|---|
| Dense sweep has 18 switching cases | 3 target loads x 6 slew values in `iqcot_dynamic_ref_slew_dense_summary.csv` | exact_match |
| `40A->20A` best scanned slew is `80 us` | dense best summary: `80`, score `2.272711` | exact_match |
| `40A->10A` best scanned slew is `80 us` | dense best summary: `80`, score `8.825046` | exact_match |
| `40A->near-0A` best scanned slew is `60 us` | dense best summary: `60`, score `16.800673` | exact_match |
| near-0A dense best undershoot is `10.452 mV` | dense best summary: `10.4520288239951` | rounding_ok |
| near-0A dense best final error is `-0.543 mV` | dense best summary: `-0.543378455996946` | rounding_ok |
| dense best improves previous `40 us` scores | recomputed improvements: `9.09%`, `5.97%`, `4.99%` | rounding_ok |

## Scope Review

| Risk | Handling | Status |
|---|---|---|
| Stale claim that `40 us` is best | Integrated paper and claim matrix now state dense best as `80/80/60 us` | PASS |
| Global optimum overclaim | Draft says current grid only, not global optimum | PASS |
| Monotonic "slower is always better" overclaim | Dense section notes near-0A `80 us` has lower undershoot but worse score than `60 us` | PASS |
| Confusing Simulink evidence with AI-in-loop evidence | Draft states this verifies `T_slew` action, not AI-in-the-loop deployment | PASS |

## Remaining Work

The next strongest experiment is no longer the `20-80 us` dense scan. It is either:

1. scan beyond `80 us` and include a settling-time penalty sweep, or
2. connect a simple delay-aware scheduler to choose `T_slew` based on cut-load severity, then test it in the same Simulink model.

