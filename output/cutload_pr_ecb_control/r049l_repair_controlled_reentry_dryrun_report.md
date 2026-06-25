# R049L Repair Phase-Boundary Controlled-Reentry Dry Run

Prepared 40A->20A crossed with two phase offsets.

- Derived model: E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx
- Plan: E:\Desktop\codex\output\cutload_pr_ecb_control\r049l_repair_controlled_reentry_plan.csv
- R049I model copied into new R049L repair derived file.
- A2 uses phase-boundary (qh1 rising edge) one-shot controlled-reentry.
- Ton truncation disabled in both A0 and A2.
- R049K-compatible operating parameters restored.

Run with `iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(true)`.
