# Dense Reference-Slew Manifest

This supplement records the dense reference-slew continuation run for the four-phase digital IQCOT / PIS-IEK research thread.

| Timestamp | Workflow | File | Stage | Description |
|---|---|---|---|---|
| 2026-06-20 11:07 | run-experiment + analyze-results | `output/iqcot_dynamic_ref_slew_dense_summary.csv` | results | Dense reference-slew sweep summary, 18 Simulink switching cases for `T_slew=20,30,40,50,60,80 us` |
| 2026-06-20 11:07 | run-experiment + analyze-results | `output/iqcot_dynamic_ref_slew_dense_best_summary.csv` | results | Best scanned trade-off points: `80 us`, `80 us`, and `60 us` for `40A->20A`, `40A->10A`, and `40A->near-0A` |
| 2026-06-20 11:07 | run-experiment + analyze-results | `output/iqcot_dynamic_ref_slew_dense_wave_samples.csv` | results | Dense reference-slew waveform samples |
| 2026-06-20 11:07 | analyze-results | `output/iqcot_dynamic_ref_slew_dense_report.md` | analysis | Auto-generated MATLAB report for the dense sweep |
| 2026-06-20 11:07 | paper-figure | `output/figures/fig23_dynamic_ref_slew_dense_sweep.png` | figure | Dense reference-slew trade-off figure |
| 2026-06-20 11:07 | analyze-results | `refine-logs/EXPERIMENT_RESULTS_REF_SLEW_DENSE_20260620_110748.md` | analysis | Clean dense reference-slew experiment report timestamped version |
| 2026-06-20 11:07 | analyze-results | `refine-logs/EXPERIMENT_RESULTS_REF_SLEW_DENSE.md` | analysis | Clean dense reference-slew experiment report latest version |
| 2026-06-20 11:07 | paper-writing | `output/iqcot_ref_slew_dense_paper_section_20260620_110748.md` | writing | Dense reference-slew paper section timestamped version |
| 2026-06-20 11:07 | paper-writing | `output/iqcot_ref_slew_dense_paper_section.md` | writing | Dense reference-slew paper section latest version |
| 2026-06-20 11:07 | paper-writing + claim-audit | `output/iqcot_integrated_research_paper_20260620_110748_dense.md` | writing | Integrated research paper updated with dense reference-slew evidence |
| 2026-06-20 11:07 | paper-claim-audit | `output/iqcot_claims_evidence_matrix_20260620_110748_dense.md` | review | Claim-evidence matrix updated with dense reference-slew evidence |
| 2026-06-20 11:07 | formula-derivation | `output/iqcot_pis_iek_derivation_package_20260620_110748_dense.md` | modeling | Derivation package updated to remove stale `20-80 us` scan TODO |

