# R049I Gentle Phase-Selective Ton-Trim Dry Run

Prepared 40A->20A crossed with two phase offsets.

- Derived model: E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx
- Plan: E:\Desktop\codex\output\cutload_pr_ecb_control\r049i_gentle_tontrim_plan.csv
- The completed R049G `.slx` model is copied into a new R049I derived file, not modified in place.
- Inherits the repaired `R049C_After_LoadStep` lower bound and per-phase guard.
- A2 uses `ton_trim_i = early_window AND qh_i` with `Tton_trunc_min=120ns`.

Run with `iqcot_r049i_pr_ecb_gentle_tontrim_chunk(true)`.
