# R038 Minimal Extrapolation Validation

R038 prepares and then executes the R037 9-row minimal extrapolation matrix for
derived-Simulink delayed-reference validation.  The wrapper
`output/iqcot_r037_minimal_extrapolation_validation.m` reuses the common R027
runner with `planMode="r037_minimal_extrapolation"`.

Execution status:

- Rows loaded: `9`
- Rows executed: `9`
- Successful rows: `9`
- Converted plan:
  `output/iqcot_r027_proxy_table_in_loop_matlab_plan_r037_minimal_extrapolation.csv`
- Dry-run report:
  `output/iqcot_r027_proxy_table_in_loop_matlab_dryrun_r037_minimal_extrapolation.md`
- Switching report:
  `output/iqcot_r038_minimal_extrapolation_report.md`
- Figure:
  `output/figures/fig51_r038_minimal_extrapolation.svg`

Validation result:

- `tau_AI=1.25us`: `42/44us` do not beat `46us`.
- `tau_AI=1.5us`: `46us` shows skip risk and `54us` is worse than `50us`.
- `tau_AI=1.75us`: `52/56us` do not beat `54us`.
- `tau_AI=2.0us`: `48us` is about `0.020` score better than `30us`, so write a local `30/44/48us` near-tie foldback band rather than a hard point optimum.

Boundary: this is derived-Simulink evidence only.  It is not hardware
validation and not a global `T_slew` optimum.
