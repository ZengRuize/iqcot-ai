# R027 proxy table-in-loop switching validation

- Plan mode: `priority_rows031_048`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows031_048.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_rows031_048.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `18`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.000 | 0.000 | 18.036 | 10.465 | 16.521 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 0.000 | 0.000 | 18.036 | 10.465 | 16.521 |
| `posterior_mode_aware_projection` | `posterior_upper_bound` | 0 | 0.000 | 0.000 | 18.036 | 10.465 | 16.521 |
| `near_opt_band_clipping` | `offline_comparator` | 0 | 0.447 | 0.517 | 18.483 | 10.355 | 21.442 |
| `fixed_40us_precommitted` | `baseline` | 1 | 1.830 | 3.177 | 19.866 | 10.897 | 21.822 |
| `fixed_80us_precommitted` | `baseline` | 1 | 3.951 | 5.298 | 21.987 | 10.151 | 47.812 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
