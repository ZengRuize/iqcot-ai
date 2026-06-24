# R029 held-out guarded-proxy switching report

## Scope

R029 executes the held-out validation matrix proposed after R028.  It uses only the derived Simulink model and delayed `Iph_ref_ts` profiles.  It is not hardware/HIL validation and does not prove a global `T_slew` optimum.

## Coverage

- Successful held-out cases: `21` / `21`.
- `10A / score_settle005`: `tau_AI = 1.5/2.5/3 us`, `T_slew = 34/40/50/62 us`.
- `near0A / score_settle010`: `tau_AI = 0/0.25/0.5 us`, `T_slew = 30/35/38 us`.

## Policy-Family Summary

| policy_family | n_cases | mean_switching_regret | max_switching_regret | mean_selected_objective | best_context_count | zero_regret_context_count |
| --- | --- | --- | --- | --- | --- | --- |
| guarded_candidate | 3 | 0.041 | 0.124 | 12.854 | 2 | 2 |
| fixed_probe | 3 | 0.105 | 0.205 | 9.568 | 1 | 1 |
| heldout_probe | 6 | 0.180 | 0.553 | 18.394 | 2 | 2 |
| dense_anchor | 6 | 0.242 | 0.661 | 14.918 | 1 | 1 |
| old_proxy_failure_probe | 3 | 0.806 | 1.236 | 10.269 | 0 | 0 |

## Context Winners

| target_label | objective | tau_ai_us | best_policy | best_slew_us | dense_anchor_regret | guarded_regret | old_proxy_regret | interpretation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle005 | 1.500 | fixed_40us_probe | 40 | 0.215 |  | 0.794 | guard threshold is not supported below 2us; 40us is best at 1.5us |
| 10A | score_settle005 | 2.500 | r028_guarded_candidate | 34 | 0.661 | 0.000 | 1.236 | R028 34us delay guard has local held-out support |
| 10A | score_settle005 | 3.000 | r028_guarded_candidate | 34 | 0.338 | 0.000 | 0.388 | R028 34us delay guard has local held-out support |
| near0A | score_settle010 | 0.000 | fine_sweep_38us_probe | 38 | 0.235 | 0.124 |  | 35us zero-delay guard is too narrow; 38us fine-sweep probe is better |
| near0A | score_settle010 | 0.250 | fine_sweep_38us_probe | 38 | 0.003 |  |  | 35us zero-delay guard is too narrow; 38us fine-sweep probe is better |
| near0A | score_settle010 | 0.500 | r028_dense_anchor | 30 | 0.000 |  |  | dense/proxy 30us action remains best once delay reaches 0.5us |

## Interpretation

- The `10A/score_settle005` delay guard has local held-out support for `tau_AI=2.5/3 us`: `34 us` is best in both contexts.
- The guard should not be extended below `2 us`: at `tau_AI=1.5 us`, `40 us` is best among the tested candidates.
- The old `62 us` proxy action remains poor for 10A held-out contexts, supporting the R028 decision to reject it.
- The near0A zero-delay `35 us` guard is too narrow once the `38 us` fine-sweep probe is included: `38 us` is best at `tau_AI=0` and marginally best at `0.25 us`, while `30 us` is best again at `0.5 us`.

Guarded-family mean regret is `0.041` over contexts where guarded rows exist; dense-anchor mean regret is `0.242` over all dense-anchor rows.  These are not directly identical policy deployments because each family appears in different subsets of the held-out matrix.

The old proxy failure probe has mean regret `0.806`, reinforcing that the old `62 us` action should remain outside the deployable band for the tested 10A settling-aware context.

## Boundary

- AI remains a supervisory scheduler and does not replace the IQCOT inner loop.
- R029 is derived Simulink evidence only.
- The near0A result updates R028: a fixed `35 us` zero-delay guard is weaker than a local `30-38 us` band/projection rule.
- These data suggest a refined R030 policy, not a final hardware-safe controller.
