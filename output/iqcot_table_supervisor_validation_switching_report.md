# Delayed table-supervisor switching validation

- Result CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval.csv`

This run uses the derived Simulink model and delayed `Iph_ref_ts` profiles. AI remains a supervisory parameter scheduler and does not replace the IQCOT inner loop.

## Policy summary

| Policy | mean base | mean score 0.05 | mean score 0.10 | mean undershoot mV | mean settle us |
|---|---:|---:|---:|---:|---:|
| `fixed_40us_precommitted` | 9.856 | 10.528 | 11.199 | 5.702 | 13.431 |
| `fixed_80us_precommitted` | 9.435 | 11.043 | 12.651 | 5.292 | 32.169 |
| `oracle_base_table` | 8.960 | 10.598 | 12.237 | 4.912 | 32.770 |
| `table_settle005` | 8.383 | 9.657 | 10.931 | 4.925 | 25.477 |
| `table_settle010` | 9.079 | 9.932 | 10.785 | 4.925 | 17.065 |

Boundary: these are switching-level delayed-reference results, not hardware validation and not proof of global T_slew optimality.
