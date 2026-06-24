# R027 proxy table-in-loop switching validation

- Plan mode: `priority_rows019_030`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows019_030.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_rows019_030.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `12`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `near_opt_band_clipping` | `offline_comparator` | 0 | 0.000 | 0.000 | 14.481 | 7.725 | 18.235 |
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.100 | 0.111 | 14.581 | 7.967 | 19.371 |
| `posterior_mode_aware_projection` | `posterior_upper_bound` | 0 | 0.100 | 0.111 | 14.581 | 7.967 | 19.371 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 0.556 | 1.001 | 15.037 | 7.967 | 21.960 |
| `fixed_40us_precommitted` | `baseline` | 1 | 0.583 | 0.973 | 15.064 | 7.954 | 19.678 |
| `fixed_80us_precommitted` | `baseline` | 1 | 1.782 | 2.314 | 16.263 | 7.391 | 41.049 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
