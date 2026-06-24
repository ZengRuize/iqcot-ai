# Local Audit R037 Short-Horizon r_hat

- Timestamp UTC: 2026-06-21T05:33:03+00:00
- Inputs: `E:\Desktop\codex\output\iqcot_r031_minimal_validation_results_combined.csv`, `E:\Desktop\codex\output\iqcot_r033_delay_band_validation_results_combined.csv`, `E:\Desktop\codex\output\iqcot_r034_transition_pocket_results_full_combined.csv`, `E:\Desktop\codex\output\iqcot_r036_dense_pair_results_combined.csv`
- Rows in local risk dataset: `51`
- Mean regrets: dense `1.116`, q_phi prior `0.020`, R037 projection `0.000`, posterior safe upper-bound `0.054`
- Oracle rejected by leave-one-delay risk gate: `1` contexts.
- Guardrail: this is post-processing of derived-Simulink rows, not hardware validation, global T_slew optimality, or proof that AI replaces IQCOT.
- Next validation plan: `E:\Desktop\codex\output\iqcot_r037_minimal_extrapolation_validation_plan.csv` with `9` rows.
