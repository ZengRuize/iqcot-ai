# Local Audit R036 Dense-Paired Boundary

- Timestamp UTC: 2026-06-21T05:06:37+00:00
- Inputs: `E:\Desktop\codex\output\iqcot_r034_transition_pocket_results_full_combined.csv`, `E:\Desktop\codex\output\iqcot_r035_folded_band_policy_surface.csv`, `E:\Desktop\codex\output\iqcot_r027_proxy_table_in_loop_results_r036_dense_pair.csv`
- New paired rows: `2`, both successful.
- Key result: `46us` at `tau_AI=1.25us` and `54us` at `tau_AI=1.75us` beat the newly simulated `30us` dense fallback in the current derived model/objective.
- Guardrail: the result is local derived-Simulink evidence only.  It is not hardware validation, global T_slew optimality, or proof that AI replaces the IQCOT inner loop.
- Claim check: `66us` remains blocked; `tau_AI=2us` still keeps `30us` fallback under R035/R031 dense-inclusive evidence.
- r_hat check: skip/settling/phase columns in `E:\Desktop\codex\output\iqcot_r036_short_horizon_rhat_training_view.csv` are labels, not online inputs.
