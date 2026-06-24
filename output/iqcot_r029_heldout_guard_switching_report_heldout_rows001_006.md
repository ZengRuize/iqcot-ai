# R029 held-out guarded-proxy switching validation

- Run label: `heldout_rows001_006`
- Result CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_heldout_rows001_006.csv`
- Policy CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_eval_heldout_rows001_006.csv`
- Context CSV: `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_eval_heldout_rows001_006.csv`

This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether R028 guarded candidates survive held-out delay contexts.

Executed rows: `6`.

## Policy-family summary

| Family | n | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |
|---|---:|---:|---:|---:|---:|---:|
| `guarded_candidate` | 1 | 0.000 | 0.000 | 9.269 | 4.292 | 15.962 |
| `fixed_probe` | 2 | 0.055 | 0.109 | 9.440 | 4.368 | 19.031 |
| `heldout_probe` | 1 | 0.128 | 0.128 | 9.630 | 4.469 | 15.858 |
| `dense_anchor` | 1 | 0.215 | 0.215 | 9.717 | 4.418 | 21.752 |
| `old_proxy_failure_probe` | 1 | 0.794 | 0.794 | 10.296 | 4.395 | 28.578 |

## Context winners

| target | objective | tau us | best policy | best slew us | dense regret | guarded regret | old proxy regret |
|---|---|---:|---|---:|---:|---:|---:|
| `10A` | `score_settle005` | 1.500 | `fixed_40us_probe` | 40.000 | 0.215 | NaN | 0.794 |
| `10A` | `score_settle005` | 2.500 | `r028_guarded_candidate` | 34.000 | NaN | 0.000 | NaN |

Boundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. The guarded policy remains a supervisory candidate, not an IQCOT inner-loop replacement.
