# R029 held-out guarded-proxy switching validation

- Run label: `heldout_rows013_021`
- Result CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_heldout_rows013_021.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_eval_heldout_rows013_021.csv`
- Context CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_eval_heldout_rows013_021.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether R028 guarded candidates survive held-out delay contexts.

Executed rows: `9`.

## Policy-family summary

| Family | n | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---:|---:|---:|---:|---:|---:|
| `dense_anchor` | 3 | 0.079 | 0.235 | 19.968 | 11.227 | 14.526 |
| `guarded_candidate` | 1 | 0.124 | 0.124 | 19.673 | 11.093 | 19.444 |
| `heldout_probe` | 5 | 0.190 | 0.553 | 20.146 | 10.849 | 20.337 |

## Context winners

| target | objective | tau us | best policy | best slew us | dense regret | guarded regret | old proxy regret |
|---|---|---:|---|---:|---:|---:|---:|
| `near0A` | `score_settle010` | 0.000 | `fine_sweep_38us_probe` | 38.000 | 0.235 | 0.124 | NaN |
| `near0A` | `score_settle010` | 0.250 | `fine_sweep_38us_probe` | 38.000 | 0.003 | NaN | NaN |
| `near0A` | `score_settle010` | 0.500 | `r028_dense_anchor` | 30.000 | 0.000 | NaN | NaN |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. The guarded policy remains a supervisory candidate, not an IQCOT inner-loop replacement.
