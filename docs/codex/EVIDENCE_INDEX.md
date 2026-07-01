# Evidence Index

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

| Experiment | Folder | Metrics CSV | Summary MD | Classification | Claim Role | Boundary |
|---|---|---|---|---|---|---|
| E010 medium load-drop | `experiments/E010_load_drop_overshoot/` | `results/current/e010_research_table.csv` | `experiments/E010_load_drop_overshoot/e010_research_summary.md` | MODEL_REVISED | Local medium `a_O` support | Not global load-drop robustness |
| E010-A5 severe load-drop boundary | `experiments/E010_load_drop_overshoot/A5_severe_drop_token/` | `e010_a5_baseline_metrics.csv`, `e010_a5_candidate_metrics.csv`, R1/R2/R3 metrics | `e010_a5_revision_synthesis.md` | MODEL_REVISED | Severe-drop negative/revision evidence | Do not claim `40A -> 1A` solved |
| E020 load-rise | `experiments/E020_load_rise_undershoot/` | `e020_metrics.csv` | `e020_research_summary.md` | MODEL_CONFIRMED | Local early `a_U` mechanism | Not full `120A` recovery |
| E020-R1 a_U window tuning | `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/` | `e020_r1_metrics.csv` | `e020_r1_research_summary.md` | MODEL_CONFIRMED | Narrow local `a_U` refinement | No `1 mV` settling by `90 us` |
| E030 balance recovery | `experiments/E030_balance_recovery/` | `e030_metrics.csv` | `e030_research_summary.md` | MODEL_REVISED | Ton_diff dominant local DC sharing actuator | Active Lambda not validated |
| E030-R3 calibration-aware guard | `experiments/E030_balance_recovery/R3_calibration_aware_guard/` | `e030_r3_metrics.csv` | `e030_r3_research_summary.md` | MODEL_CONFIRMED | Local sensing-aware `a_S` guard | No broad or imperfect-calibration robustness |
| E040-A-R1 add-phase integrity | `experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/` | `e040_a_r1_metrics.csv` | `e040_a_r1_research_summary.md` | MODEL_CONFIRMED | Local `2 -> 4` add event integrity | No severe load-rise or efficiency claim |
| E040-S1 shed-phase handoff | `experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/` | `e040_s1_metrics.csv` | `e040_s1_research_summary.md` | MODEL_CONFIRMED | Local `4 -> [1,3]` shed event integrity | No broad active-phase scheduling |

## Manuscript Evidence Package

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

| Package | Folder | Key Files | Classification | Claim Role | Boundary |
|---|---|---|---|---|---|
| Manuscript evidence package | `papers/current/manuscript_evidence_package/` | `00_evidence_index.md`; `03_figure_plan.md`; `04_table_plan.md`; `05_results_to_text_mapping.md`; `07_latex_manuscript_outline.md` | manuscript documentation / evidence packaging | Converts existing local IQCOT evidence into paper-ready figure/table/claim scaffolding | Does not add new simulation evidence or expand claims |
