# Long Reference-Slew and Settling-Aware Manifest

This supplement records the long reference-slew continuation run and the settling-aware objective sensitivity analysis.

| Timestamp | Workflow | File | Stage | Description |
|---|---|---|---|---|
| 2026-06-20 11:19 | run-experiment | `output/iqcot_dynamic_ref_slew_long_summary.csv` | results | Long reference-slew sweep summary, 9 Simulink switching cases for `T_slew=80,100,120 us` |
| 2026-06-20 11:19 | run-experiment | `output/iqcot_dynamic_ref_slew_long_best_summary.csv` | results | Long-grid best points; near-zero long-only best is `120 us` but with `71.408 us` settling |
| 2026-06-20 11:20 | analyze-results | `output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv` | results | Combined dense + long scores over `20-120 us` |
| 2026-06-20 11:20 | analyze-results | `output/iqcot_dynamic_ref_slew_settle_penalty_best.csv` | results | Settling-time penalty sensitivity: base `80/80/60 us`, light penalty `30/50/60 us`, medium penalty `30/30/30 us` |
| 2026-06-20 11:20 | paper-figure | `output/figures/fig24_ref_slew_settle_penalty.png` | figure | Score and settling-time sensitivity figure |
| 2026-06-20 11:20 | analyze-results | `refine-logs/EXPERIMENT_RESULTS_REF_SLEW_LONG_SETTLE_20260620_112033.md` | analysis | Clean long-slew and settling-aware experiment report timestamped version |
| 2026-06-20 11:20 | analyze-results | `refine-logs/EXPERIMENT_RESULTS_REF_SLEW_LONG_SETTLE.md` | analysis | Clean long-slew and settling-aware experiment report latest version |
| 2026-06-20 11:20 | paper-writing | `output/iqcot_ref_slew_long_settle_paper_section_20260620_112033.md` | writing | Long-slew and objective-sensitivity paper section timestamped version |
| 2026-06-20 11:20 | paper-writing | `output/iqcot_ref_slew_long_settle_paper_section.md` | writing | Long-slew and objective-sensitivity paper section latest version |
| 2026-06-20 11:23 | paper-writing + claim-audit | `output/iqcot_integrated_research_paper_20260620_112343_long_settle.md` | writing | Integrated paper updated with long-slew and settling-aware evidence |
| 2026-06-20 11:23 | paper-claim-audit | `output/iqcot_claims_evidence_matrix_20260620_112343_long_settle.md` | review | Claim-evidence matrix updated with objective-sensitive reference-slew claim |
| 2026-06-20 11:23 | formula-derivation | `output/iqcot_pis_iek_derivation_package_20260620_112343_long_settle.md` | modeling | Derivation package updated to avoid fixed optimal reference-slew framing |

