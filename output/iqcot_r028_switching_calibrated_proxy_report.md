# R028 switching-calibrated proxy projection

## Scope

R028 reuses the completed R027 priority derived-Simulink matrix to recalibrate the deployable risk-proxy projection.  No original `.slx` file is modified, no `.slx` XML is edited, and no hardware/HIL claim is made.

## What Failed In R027

- In `10A / score_settle005`, the old calibrated proxy repeatedly selected `62 us`; the switching replay favored the dense-long `50 us` row for `tau_AI=0/0.5/1 us`, and a short `34 us` comparator at `tau_AI=2 us`.
- In `near0A / score_settle010`, the old proxy and dense table selected `30 us`, which tied for best once delay was present; at zero delay the `35 us` comparator was slightly better.
- Therefore the R026 proxy is useful as an interface, but its safety band was not calibrated to switching-level delay stress.

## R028 Policies

- `r028_dense_anchor_proxy`: deployable conservative rule.  It keeps the proxy only when it stays inside a context-dependent dense-table band, otherwise it projects back to the dense-long table action.
- `r028_switching_guarded_proxy`: stress-calibrated candidate.  It starts from the dense-anchor rule and adds two R027-fitted guards: use the short `34 us` comparator for `10A/score_settle005/tau>=2 us`, and use `35 us` for `near0A/score_settle010/tau=0 us`.  This row is a candidate for held-out validation, not a final deployable proof.

## Priority Switching Replay Summary

| policy | n_cases | mean_switching_regret | max_switching_regret | mean_settle_time_us | best_context_count | zero_regret_context_count |
| --- | --- | --- | --- | --- | --- | --- |
| r028_switching_guarded_proxy | 8 | 0.000 | 0.000 | 18.946 | 2 | 8 |
| discrete_dense_long_table | 8 | 0.025 | 0.111 | 19.230 | 6 | 6 |
| posterior_mode_aware_projection | 8 | 0.025 | 0.111 | 19.230 | 0 | 6 |
| r028_dense_anchor_proxy | 8 | 0.025 | 0.111 | 19.230 | 0 | 6 |
| near_opt_band_clipping | 8 | 0.257 | 0.517 | 18.037 | 0 | 2 |
| calibrated_risk_proxy_projection | 8 | 0.283 | 1.001 | 22.173 | 0 | 3 |
| fixed_40us_precommitted | 8 | 0.971 | 3.177 | 19.678 | 0 | 0 |
| fixed_80us_precommitted | 8 | 2.171 | 5.298 | 41.049 | 0 | 0 |

Key numeric outcome:

- Old calibrated proxy mean switching regret: `0.283`.
- Dense-long table mean switching regret: `0.025`.
- R028 dense-anchor proxy mean switching regret: `0.025`.
- R028 guarded candidate mean switching regret: `0.000`.
- Near-opt comparator mean switching regret: `0.257`.

The conservative dense-anchor rule removes the `62 us` proxy failure and ties the dense-long table on this priority replay.  The guarded candidate attains zero regret on the same priority contexts because it is calibrated from those contexts; it must therefore be treated as a hypothesis for R029 held-out simulation, not as independent proof.

## Failure And Guard Table

| target_label | objective | tau_ai_us | dense_slew_us | proxy_slew_us | dense_anchor_slew_us | guarded_slew_us | proxy_regret | dense_anchor_regret | guarded_regret |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10A | score_settle005 | 0.000 | 50.000 | 62.000 | 50.000 | 50.000 | 0.355 | 0.000 | 0.000 |
| 10A | score_settle005 | 0.500 | 50.000 | 62.000 | 50.000 | 50.000 | 0.191 | 0.000 | 0.000 |
| 10A | score_settle005 | 1.000 | 50.000 | 62.000 | 50.000 | 50.000 | 0.607 | 0.000 | 0.000 |
| 10A | score_settle005 | 2.000 | 50.000 | 62.000 | 50.000 | 34.000 | 1.001 | 0.089 | 0.000 |
| near0A | score_settle010 | 0.000 | 30.000 | 30.000 | 30.000 | 35.000 | 0.111 | 0.111 | 0.000 |
| near0A | score_settle010 | 0.500 | 30.000 | 30.000 | 30.000 | 30.000 | 0.000 | 0.000 | 0.000 |
| near0A | score_settle010 | 1.000 | 30.000 | 30.000 | 30.000 | 30.000 | 0.000 | 0.000 | 0.000 |
| near0A | score_settle010 | 2.000 | 30.000 | 30.000 | 30.000 | 30.000 | 0.000 | 0.000 | 0.000 |

## Offline R026 Replay Check

| policy | n_cases | mean_offline_regret | max_offline_regret |
| --- | --- | --- | --- |
| combined_grid_oracle | 45 | 0.000 | 0.000 |
| r028_dense_anchor_proxy | 45 | 0.099 | 0.235 |
| near_opt_band_clipping | 45 | 0.101 | 0.209 |
| r028_switching_guarded_proxy | 45 | 0.106 | 0.235 |
| calibrated_risk_proxy_projection | 45 | 0.119 | 0.355 |
| discrete_dense_long_table | 45 | 0.163 | 0.490 |

The offline replay is included only as a consistency check over the R026 grid.  It is not a substitute for switching-level re-simulation because R027 already showed that offline ranking can fail under delayed-reference replay.

## Boundary

- AI remains a supervisory scheduler of `T_slew` or related parameters and does not replace the IQCOT inner loop.
- R028 does not prove a global optimum for `T_slew`.
- R028 does not prove hardware performance, neural-network AI-in-loop superiority, or exact first-peak prediction by PIS-IEK.
- The guarded candidate is intentionally conservative in claims: it converts R027 failure evidence into a next validation design.
