# R027 MATLAB proxy table-in-loop dry run

Plan mode: `priority_rows007_018`.

Plan CSV: `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_priority_rows007_018.csv`.

Rows: `12`.

Policies: `fixed_40us_precommitted`, `fixed_80us_precommitted`, `discrete_dense_long_table`, `calibrated_risk_proxy_projection`, `near_opt_band_clipping`, `posterior_mode_aware_projection`.

This dry run did not execute Simulink. It verified that R027 CSV rows can be loaded by MATLAB and converted into delayed `Iph_ref_ts` cases.

Boundary: R027 dry-run and offline expected scores are not switching-level or hardware validation. AI remains a supervisory parameter scheduler.
