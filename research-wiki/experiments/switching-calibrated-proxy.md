# R028 switching-calibrated proxy safety projection

## Purpose

R028 responds to the R027 stress replay failure of the calibrated `r_hat(z,T_slew)` proxy.  It does not run new Simulink cases; it reuses the completed R027 priority switching results to recalibrate the safety projection `B_epsilon(z,r_hat,tau_AI)`.

## Inputs

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_context_summary_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_eval.csv`

## Outputs

- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv`
- `E:/Desktop/codex/output/iqcot_r028_context_failure_analysis.csv`
- `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_report.md`
- `E:/Desktop/codex/output/figures/fig36_r028_switching_calibrated_proxy.svg`

## Result

| policy | priority mean switching regret | interpretation |
|---|---:|---|
| dense-long table | `0.025` | strong deployable baseline |
| old calibrated proxy | `0.283` | failed in 10A/settling-aware stress contexts |
| R028 dense-anchor proxy | `0.025` | conservative deployable projection; ties dense-long |
| R028 guarded candidate | `0.000` | stress-fitted candidate; needs held-out validation |

The conservative dense-anchor rule projects the old proxy back to the dense-long action when the proxy leaves the switching-calibrated band.  It fixes the known `10A/score_settle005` `62us` failure.  The guarded rule adds two pressure-fitted actions, `34us` for `10A/score_settle005/tau_AI>=2us` and `35us` for `near0A/score_settle010/tau_AI=0`.

## Boundary

R028 is post-processing over completed derived Simulink rows.  It is not hardware/HIL validation and does not prove that AI or proxy scheduling globally outperforms dense-long lookup.  The guarded candidate must be tested on held-out derived Simulink contexts before stronger claims.
