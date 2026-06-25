# R049N Independent-Clock Reentry Dry Run

Prepared 40A->20A crossed with two phase offsets.

- Derived model: E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
- Plan: E:\Desktop\codex\output\cutload_pr_ecb_control\r049n_independent_clock_reentry_plan.csv
- Source: R049L repair derived model.
- A2 uses an independent upstream timer / predicted-slot one-shot reentry.
- Release clock threshold: `t_load_step + 1.685 us`.
- Ton truncation disabled in both A0 and A2.

Run with `iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(true)`.
