# R021 Table-Supervisor Delay Sensitivity

## Status

PASS / PARTIAL CLAIM

Date: 2026-06-20

## Purpose

Extend R020 beyond the single `tau_AI=5 us` slice by running table-supervisor
delayed-reference switching validation at `tau_AI=0.5/1/2 us`, then combine
with the previous `5 us` result and the zero-delay reference ordering.

## Model And Script

- Derived model only:
  `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
- Runner:
  `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`
- Postprocess:
  `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity.py`
- No original `.slx` was modified.
- No `.slx` XML was edited.

## Matrix

- New switching cases: `45`
  - `tau_AI=0.5/1/2 us`
  - 3 cut-load cases
  - 5 policies
- Existing R020 switching cases: `15`
  - `tau_AI=5 us`
- Total positive-delay switching cases: `60`

## Key Results

Best-by-tau:

| tau_AI | best base | best 0.05 | best 0.10 |
|---:|---|---|---|
| `0 us` | `oracle_base_table` | `table_settle005` | `table_settle010` |
| `0.5 us` | `oracle_base_table` | `table_settle010` | `table_settle010` |
| `1 us` | `oracle_base_table` | `table_settle010` | `table_settle010` |
| `2 us` | `table_settle005` | `table_settle005` | `table_settle005` |
| `5 us` | `table_settle005` | `table_settle005` | `table_settle010` |

## Interpretation

The best table policy depends jointly on objective weight and parameter-commit
delay.  The result does not support a single fixed `T_slew`, nor a simple
monotonic delay rule.  It supports conditioning the supervisory policy on both
`alpha_settle` and `tau_AI/delay_events`.

## Boundary

This is still table-in-loop delayed-reference validation, not neural-network
AI-in-loop and not hardware/HIL.  IQCOT inner-loop event triggering is unchanged.

## Outputs

- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval_tau0p5_1_2us.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_by_tau.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_report.md`
- `E:/Desktop/codex/output/figures/fig28_table_supervisor_delay_sensitivity.svg`

## Next

Move from table-driven labels to a simple supervised regressor or rule-based
AI supervisor and compare it against the table policy in the same delayed
reference framework.
