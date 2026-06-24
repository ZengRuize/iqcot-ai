# Table-in-loop AI Supervisor Validation Matrix

## Purpose

This artifact advances the four-phase digital IQCOT / PIS-IEK study from a
training-label design to an executable table-in-loop validation plan.  It does
not introduce a new switching run by itself.  The delayed switching run should
be executed with `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`.

## Generated files

- Plan CSV: `E:/Desktop/codex/output/iqcot_table_supervisor_validation_plan.csv`
- Zero-delay reference evaluation: `E:/Desktop/codex/output/iqcot_table_supervisor_zero_delay_reference_eval.csv`
- Figure: `E:/Desktop/codex/output/figures/fig26_table_supervisor_zero_delay_reference.svg`
- Companion MATLAB runner: `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`

## Matrix

- Target cut-load cases: `40A->20A`, `40A->10A`, `40A->near-0A`
- FPGA latency contexts: `[0.0, 0.5, 1.0, 2.0, 5.0]` us
- Event period assumption: `0.5` us
- Planned rows: `75`
- Policies: `fixed_40us_precommitted, fixed_80us_precommitted, oracle_base_table, table_settle005, table_settle010`

For fixed precommitted baselines, `ref_start_delay_us_for_simulink=0`.  For
table-driven policies, the delayed Simulink runner should start the reference
ramp at `t_load_step + tau_AI`, which represents parameter computation and
commit delay.  This is still an equivalent delayed-reference experiment, not a
neural-network-in-the-loop hardware result.

## Zero-delay reference ordering

The completed dense+long Simulink sweep gives the following reference ordering
before adding parameter-commit delay:

| Policy | 20A | 10A | near-0A | mean base | mean score 0.05 | mean score 0.10 |
|---|---:|---:|---:|---:|---:|---:|
| `fixed_40us_precommitted` | 40.0 | 40.0 | 40.0 | 9.856 | 10.528 | 11.199 |
| `fixed_80us_precommitted` | 80.0 | 80.0 | 80.0 | 9.435 | 11.043 | 12.651 |
| `oracle_base_table` | 80.0 | 80.0 | 60.0 | 9.299 | 10.700 | 12.100 |
| `table_settle005` | 30.0 | 50.0 | 60.0 | 9.409 | 10.356 | 11.303 |
| `table_settle010` | 30.0 | 30.0 | 30.0 | 10.251 | 10.683 | 11.115 |

The best zero-delay base-score policy is `oracle_base_table` with mean base
score `9.299`.  The best zero-delay
`score+0.05*T_settle` policy is `table_settle005` with score
`10.356`.  The best zero-delay
`score+0.10*T_settle` policy is `table_settle010` with score
`11.115`.

## Interpretation boundary

This matrix is a bridge, not a final AI claim.  It tells the next Simulink run
exactly which `T_slew` and `ref_start_delay` values to inject into the existing
`From Workspace` reference path.  Only after running the companion MATLAB script
with switching waveforms should the paper claim whether the ordering is
preserved under microsecond parameter-commit delay.
