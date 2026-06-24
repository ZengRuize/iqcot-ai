# R029 held-out validation of R028 guarded proxy

## Purpose

R029 tests whether the R028 guarded proxy candidate is overfitted to the R027 priority stress set.  It executes a small held-out derived Simulink matrix and keeps all claims bounded to supervisory `T_slew` scheduling.

## Inputs

- `E:/Desktop/codex/output/iqcot_r029_guarded_heldout_plan.csv`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

## Outputs

- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_validation.m`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_combined_report.md`
- `E:/Desktop/codex/output/figures/fig38_r029_heldout_guard_combined.svg`

## Result

All `21` held-out derived Simulink cases succeeded.

| context | best result | interpretation |
|---|---|---|
| `10A / score_settle005 / tau=1.5us` | `40us` | do not extend the 34us guard below 2us |
| `10A / score_settle005 / tau=2.5us` | `34us` | supports the short-slew delay guard |
| `10A / score_settle005 / tau=3us` | `34us` | supports the short-slew delay guard |
| `near0A / score_settle010 / tau=0us` | `38us` | fixed 35us guard is too narrow |
| `near0A / score_settle010 / tau=0.25us` | `38us` | local band should include 38us |
| `near0A / score_settle010 / tau=0.5us` | `30us` | dense/proxy action returns as best once delay is present |

## Boundary

R029 is derived Simulink evidence, not hardware/HIL validation.  It refines the R028 guarded proxy into a local-band policy; it does not prove global optimality or neural-network AI-in-loop superiority.
