# R027 proxy table-in-loop switching validation

- Plan mode: `priority`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `6`. This file is a smoke test of the R027 runner and derived-model interface, not complete priority-matrix evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.000 | 0.000 | 10.008 | 4.847 | 20.538 |
| `posterior_mode_aware_projection` | `posterior_upper_bound` | 0 | 0.000 | 0.000 | 10.008 | 4.847 | 20.538 |
| `near_opt_band_clipping` | `offline_comparator` | 0 | 0.209 | 0.209 | 10.217 | 5.146 | 15.228 |
| `fixed_40us_precommitted` | `baseline` | 1 | 0.254 | 0.254 | 10.262 | 5.010 | 17.534 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 0.355 | 0.355 | 10.363 | 4.739 | 27.386 |
| `fixed_80us_precommitted` | `baseline` | 1 | 0.531 | 0.531 | 10.539 | 4.631 | 34.286 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
