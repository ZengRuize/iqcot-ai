# R029 held-out guarded-proxy switching validation

- Run label: `heldout_rows007_012`
- Result CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_heldout_rows007_012.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_eval_heldout_rows007_012.csv`
- Context CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_eval_heldout_rows007_012.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether R028 guarded candidates survive held-out delay contexts.

Executed rows: `6`.

## Policy-family summary

| Family | n | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---:|---:|---:|---:|---:|---:|
| `guarded_candidate` | 1 | 0.000 | 0.000 | 9.618 | 4.292 | 17.556 |
| `dense_anchor` | 2 | 0.169 | 0.338 | 9.943 | 4.292 | 25.087 |
| `fixed_probe` | 1 | 0.205 | 0.205 | 9.823 | 4.292 | 21.040 |
| `old_proxy_failure_probe` | 2 | 0.481 | 0.575 | 10.256 | 4.292 | 30.542 |

## Context winners

| target | objective | tau us | best policy | best slew us | dense regret | guarded regret | old proxy regret |
|---|---|---:|---|---:|---:|---:|---:|
| `10A` | `score_settle005` | 2.500 | `r028_dense_anchor` | 50.000 | 0.000 | NaN | 0.575 |
| `10A` | `score_settle005` | 3.000 | `r028_guarded_candidate` | 34.000 | 0.338 | 0.000 | 0.388 |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. The guarded policy remains a supervisory candidate, not an IQCOT inner-loop replacement.
