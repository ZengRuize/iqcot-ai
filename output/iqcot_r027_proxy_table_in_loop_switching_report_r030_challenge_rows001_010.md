# R027 proxy table-in-loop switching validation

- Plan mode: `r030_challenge_rows001_010`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r030_challenge_rows001_010.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_r030_challenge_rows001_010.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `10`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `discrete_dense_long_table` | `deployable_baseline` | 1 | 0.161 | 0.490 | 10.380 | 4.703 | 12.260 |
| `calibrated_risk_proxy_projection` | `deployable_candidate` | 1 | 0.170 | 0.692 | 10.389 | 4.680 | 13.757 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
