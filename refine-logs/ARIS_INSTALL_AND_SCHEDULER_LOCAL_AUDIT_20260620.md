# Local Audit: ARIS Install and Reference-Slew Scheduler Update

**Date**: 2026-06-20
**Overall**: PASS

| Check | Status | Detail |
|---|---:|---|
| `external\aris_repo` | PASS | exists |
| `.aris\installed-skills-codex.txt` | PASS | exists |
| `.agents\skills\research-wiki\SKILL.md` | PASS | exists |
| `RESEARCH_BRIEF.md` | PASS | exists |
| `research-wiki\index.md` | PASS | exists |
| `research-wiki\ideas\iqcot-pis-iek-four-phase.md` | PASS | exists |
| `research-wiki\experiments\ref-slew-dense-long-sweep.md` | PASS | exists |
| `research-wiki\experiments\ref-slew-scheduler-policy-eval.md` | PASS | exists |
| `research-wiki\claims\objective-sensitive-ref-slew.md` | PASS | exists |
| `output\iqcot_ref_slew_scheduler_policy_eval.csv` | PASS | exists |
| `output\iqcot_ref_slew_scheduler_policy_eval_detail.csv` | PASS | exists |
| `output\figures\fig25_ref_slew_scheduler_policy_eval.png` | PASS | exists |
| `refine-logs\EXPERIMENT_RESULTS_REF_SLEW_SCHEDULER.md` | PASS | exists |
| `output\iqcot_ref_slew_scheduler_paper_section.md` | PASS | exists |
| `winner_mean_base_score` | PASS | oracle_base_score 9.299 |
| `winner_score_settle005` | PASS | scheduler_settle005 10.356 |
| `winner_score_settle010` | PASS | fixed_30us 11.115 |
| `paper_section_no_question_mark_corruption` | PASS | question_mark_count=0 |
| `fig25_nontrivial_size` | PASS | 62170 |
| `output/iqcot_integrated_research_paper.md:mentions_policy_eval` | PASS |  |
| `output/iqcot_claims_evidence_matrix.md:mentions_policy_eval` | PASS |  |
| `output/iqcot_pis_iek_derivation_package.md:mentions_policy_eval` | PASS |  |

## Interpretation

- ARIS Codex skills are installed project-locally and the research wiki is initialized.
- The new policy evaluation reproduces objective-dependent winners: base-score oracle `80/80/60 us`, settling-aware 0.05 scheduler `30/50/60 us`, and strong settling penalty `30/30/30 us`.
- This supports the bounded claim that `T_slew` is an objective-sensitive scheduling variable for AI supervisory control, not a fixed global optimum.
- The result remains offline post-processing of Simulink sweep data, not AI-in-the-loop or hardware validation.