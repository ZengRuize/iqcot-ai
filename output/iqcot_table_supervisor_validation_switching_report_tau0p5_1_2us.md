# Delayed table-supervisor switching validation

- Result CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval_tau0p5_1_2us.csv`

This run uses the derived Simulink model and delayed `Iph_ref_ts` profiles. AI remains a supervisory parameter scheduler and does not replace the IQCOT inner loop.

## Policy summary

| Policy | mean base | mean score 0.05 | mean score 0.10 | mean undershoot mV | mean settle us |
|---|---:|---:|---:|---:|---:|
| `fixed_40us_precommitted` | 9.856 | 10.528 | 11.199 | 5.702 | 13.431 |
| `fixed_80us_precommitted` | 9.435 | 11.043 | 12.651 | 5.292 | 32.169 |
| `oracle_base_table` | 8.719 | 10.146 | 11.574 | 5.122 | 28.544 |
| `table_settle005` | 8.890 | 9.883 | 10.875 | 5.168 | 19.847 |
| `table_settle010` | 9.501 | 9.975 | 10.449 | 5.393 | 9.481 |

Boundary: these are switching-level delayed-reference results, not hardware validation and not proof of global T_slew optimality.
