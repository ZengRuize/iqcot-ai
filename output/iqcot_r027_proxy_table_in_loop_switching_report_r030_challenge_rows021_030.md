# R027 proxy table-in-loop switching validation

- Plan mode: `r030_challenge_rows021_030`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows021_030.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_r030_challenge_rows021_030.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `10`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.357 | 1.688 | 2.934 | 1.095 | 2.650 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 1.430 | 2.793 | 4.007 | 1.031 | 11.270 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
