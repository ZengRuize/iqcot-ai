# Reference-Slew Scheduler Policy Evaluation

**Date**: 2026-06-20
**Source data**: `output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`
**Scope**: offline post-processing of existing four-phase IQCOT Simulink switching-level sweep; no new Simulink run in this step.

## Policies

- `fixed_30us`, `fixed_40us`, `fixed_60us`, `fixed_80us`: same reference slew for all load-drop targets.
- `oracle_base_score`: chooses per-load `T_slew` minimizing the original base score.
- `scheduler_settle005`: chooses per-load `T_slew` minimizing `base score + 0.05 * settle_time_us`.
- `scheduler_settle010`: chooses per-load `T_slew` minimizing `base score + 0.10 * settle_time_us`.

## Summary

| policy | T20/T10/Tnear0 us | mean undershoot mV | mean settle us | mean phase std ns | mean base | mean score005 | mean score010 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fixed_30us | 30/30/30 | 6.038 | 8.640 | 84.518 | 10.251 | 10.683 | 11.115 |
| fixed_40us | 40/40/40 | 5.702 | 13.431 | 81.826 | 9.856 | 10.528 | 11.199 |
| fixed_60us | 60/60/60 | 5.448 | 24.809 | 77.438 | 10.182 | 11.422 | 12.663 |
| fixed_80us | 80/80/80 | 5.292 | 32.169 | 80.949 | 9.435 | 11.043 | 12.651 |
| oracle_base_score | 80/80/60 | 5.392 | 28.009 | 69.862 | 9.299 | 10.700 | 12.100 |
| scheduler_settle005 | 30/50/60 | 5.522 | 18.935 | 69.047 | 9.409 | 10.356 | 11.303 |
| scheduler_settle010 | 30/30/30 | 6.038 | 8.640 | 84.518 | 10.251 | 10.683 | 11.115 |

## Key Observations

- Lowest mean base score: `oracle_base_score` with selected slews `80/80/60 us` and mean base score `9.299`.
- Lowest mean settling-aware 0.05 score: `scheduler_settle005` with selected slews `30/50/60 us` and mean score `10.356`.
- Lowest mean settling-aware 0.10 score: `fixed_30us` with selected slews `30/30/30 us` and mean score `11.115`.
- The policy ranking changes with the objective, which strengthens the paper wording that reference slew is an objective-sensitive scheduling variable rather than a fixed global optimum.
- The result is not AI-in-the-loop yet. It is an oracle/surrogate policy check that defines what an AI supervisory layer should learn to approximate under explicit constraints.

## Outputs

- `output/iqcot_ref_slew_scheduler_policy_eval.csv`
- `output/iqcot_ref_slew_scheduler_policy_eval_detail.csv`
- `output/figures/fig25_ref_slew_scheduler_policy_eval.png`
