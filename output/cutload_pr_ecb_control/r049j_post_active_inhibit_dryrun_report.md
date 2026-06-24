# R049J Deferred Post-Active Pulse-Inhibit Dry Run

Prepared 40A->20A crossed with two phase offsets.

- Derived model: E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx
- Plan: E:\Desktop\codex\output\cutload_pr_ecb_control\r049j_post_active_inhibit_plan.csv
- The completed R049I `.slx` model is copied into a new R049J derived file, not modified in place.
- A2 uses request-path `post_active_inhibit` after the baseline active pulse's natural end.
- Ton truncation is disabled in both A0 and A2.

Run with `iqcot_r049j_pr_ecb_post_active_inhibit_chunk(true)`.
