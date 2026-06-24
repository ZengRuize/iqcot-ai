# R049G Phase-Selective Ton-Truncation Dry Run

Prepared 40A->20A crossed with two phase offsets.

- Derived model: E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx
- Plan: E:\Desktop\codex\output\cutload_pr_ecb_control\r049g_phase_selective_tontrunc_plan.csv
- The completed R049F `.slx` model is copied, not modified.
- Repairs `R049C_After_LoadStep` by explicitly connecting `t_load_step`.
- Per-phase control: `ton_truncate_i = early_window AND qh_i`.

Run with `iqcot_r049g_pr_ecb_phase_selective_tontrunc_chunk(true)`.
