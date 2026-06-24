# R027 priority table-in-loop combined switching report

## Scope

This report combines all completed chunks of the R027 priority matrix. It uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It is not hardware/HIL validation and does not prove a global `T_slew` optimum.

## Coverage

- Priority plan rows: `48`.
- Combined switching rows: `48`.
- Unique cases: `48`.
- Successful cases: `48`.
- Missing priority cases: `0`.

## Policy Summary

| policy | n_cases | mean_switching_regret | max_switching_regret | mean_selected_objective | best_context_count | zero_regret_context_count | mean_settle_time_us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| discrete_dense_long_table | 8 | 0.025 | 0.111 | 14.117 | 6 | 6 | 19.230 |
| posterior_mode_aware_projection | 8 | 0.025 | 0.111 | 14.117 | 0 | 6 | 19.230 |
| near_opt_band_clipping | 8 | 0.257 | 0.517 | 14.349 | 2 | 2 | 18.037 |
| calibrated_risk_proxy_projection | 8 | 0.283 | 1.001 | 14.376 | 0 | 3 | 22.173 |
| fixed_40us_precommitted | 8 | 0.971 | 3.177 | 15.064 | 0 | 0 | 19.678 |
| fixed_80us_precommitted | 8 | 2.171 | 5.298 | 16.263 | 0 | 0 | 41.049 |

## Context Summary

| target_label | objective | tau_ai_us | switching_best_policy | switching_best_slew_us | offline_best_policy_within_priority | ranking_preserved | proxy_regret | dense_regret |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle005 | 0.000 | discrete_dense_long_table | 50 | discrete_dense_long_table | True | 0.355 | 0.000 |
| 10A | score_settle005 | 0.500 | discrete_dense_long_table | 50 | discrete_dense_long_table | True | 0.191 | 0.000 |
| 10A | score_settle005 | 1.000 | discrete_dense_long_table | 50 | discrete_dense_long_table | True | 0.607 | 0.000 |
| 10A | score_settle005 | 2.000 | near_opt_band_clipping | 34 | discrete_dense_long_table | False | 1.001 | 0.089 |
| near0A | score_settle010 | 0.000 | near_opt_band_clipping | 35 | near_opt_band_clipping | True | 0.111 | 0.111 |
| near0A | score_settle010 | 0.500 | calibrated_risk_proxy_projection | 30 | near_opt_band_clipping | False | 0.000 | 0.000 |
| near0A | score_settle010 | 1.000 | calibrated_risk_proxy_projection | 30 | near_opt_band_clipping | False | 0.000 | 0.000 |
| near0A | score_settle010 | 2.000 | calibrated_risk_proxy_projection | 30 | near_opt_band_clipping | False | 0.000 | 0.000 |

## Proxy vs Dense-Long

- Proxy better than dense-long in `0` / `8` priority contexts.
- Proxy tied dense-long in `4` / `8` contexts.
- Proxy worse than dense-long in `4` / `8` contexts.
- Offline best policy within the priority subset was preserved in `4` / `8` contexts.

Key interpretation: the R026 offline average advantage of calibrated risk proxy does not survive this stress-selected R027 priority switching replay. Dense-long table and posterior rows have the lowest mean switching regret, while calibrated proxy is useful as an interface but requires re-calibration of the safety projection before stronger AI claims.

## Boundary

- AI remains a supervisory parameter scheduler and does not replace IQCOT inner loop.
- Posterior mode-aware projection is an upper-bound comparator, not deployable AI.
- Near-opt band is an offline comparator, not a hardware safety set.
- This priority replay is derived Simulink evidence, not hardware validation.
