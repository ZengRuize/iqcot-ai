# R027 proxy table-in-loop switching validation

- Plan mode: `priority_rows007_018`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_rows007_018.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_rows007_018.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `12`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.000 | 0.000 | 9.831 | 4.607 | 22.500 |
| `posterior_mode_aware_projection` | `posterior_upper_bound` | 0 | 0.000 | 0.000 | 9.831 | 4.607 | 22.500 |
| `near_opt_band_clipping` | `offline_comparator` | 0 | 0.252 | 0.347 | 10.082 | 4.747 | 14.137 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 0.399 | 0.607 | 10.230 | 4.536 | 28.257 |
| `fixed_40us_precommitted` | `baseline` | 1 | 0.431 | 0.579 | 10.262 | 5.010 | 17.534 |
| `fixed_80us_precommitted` | `baseline` | 1 | 0.709 | 0.857 | 10.539 | 4.631 | 34.286 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
