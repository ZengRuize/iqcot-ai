# MATLAB table-supervisor validation dry run

Plan CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_plan_matlab.csv`.

Rows: `75`.

This dry run did not execute Simulink. It verified the policy matrix and the delayed reference-start values that will be injected through `Iph_ref_ts`.

Boundary: delayed `Iph_ref_ts` emulates parameter commit latency. It is not a neural-network-in-the-loop or hardware result.
