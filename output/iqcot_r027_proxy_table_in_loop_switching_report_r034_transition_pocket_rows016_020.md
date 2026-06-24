# R027 proxy table-in-loop switching validation

- Plan mode: `r034_transition_pocket_rows016_020`
- Result CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r034_transition_pocket_rows016_020.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_r034_transition_pocket_rows016_020.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether the R026 calibrated risk proxy ordering survives switching-level replay.

Executed rows: `5`. Treat small `maxCases` runs as interface smoke tests, not complete R027 evidence.

## Policy summary

| Policy | role | online inputs | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---|---:|---:|---:|---:|---:|---:|
| `r034_transition_pocket_candidate` | `candidate` | 1 | 0.306 | 0.695 | 2.580 | 0.992 | 5.454 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. Posterior mode-aware rows remain upper-bound comparators, not deployable AI.
