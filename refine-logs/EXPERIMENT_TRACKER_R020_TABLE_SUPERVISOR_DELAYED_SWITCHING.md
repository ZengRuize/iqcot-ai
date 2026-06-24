# R020 Table-Supervisor Delayed Switching Validation

## Status

PASS / PARTIAL CLAIM

Date: 2026-06-20

## Purpose

Validate whether the supervised/table-driven `T_slew` labels can be injected
into the derived four-phase IQCOT switching model under an equivalent FPGA
parameter-commit delay.

## Model And Script

- Derived model only:
  `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`
- Runner:
  `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m`
- No original `.slx` was modified.
- No `.slx` XML was edited.

## Matrix

- `tau_AI = 5 us`, equivalent to about `10` IQCOT event slots at `T_event=0.5 us`.
- 3 cut-load cases: `40A->20A`, `40A->10A`, `40A->near-0A`.
- 5 policies:
  - fixed `40 us`, precommitted
  - fixed `80 us`, precommitted
  - base-score table: `80/80/60 us`
  - `alpha=0.05` table: `30/50/60 us`
  - `alpha=0.10` table: `30/30/30 us`
- 15 switching cases completed successfully.

## Key Results

| Policy | mean base | mean score 0.05 | mean score 0.10 | mean undershoot | mean settling |
|---|---:|---:|---:|---:|---:|
| fixed `40 us` | `9.856` | `10.528` | `11.199` | `5.702 mV` | `13.431 us` |
| fixed `80 us` | `9.435` | `11.043` | `12.651` | `5.292 mV` | `32.169 us` |
| base-score table | `8.960` | `10.598` | `12.237` | `4.912 mV` | `32.770 us` |
| `alpha=0.05` table | `8.383` | `9.657` | `10.931` | `4.925 mV` | `25.477 us` |
| `alpha=0.10` table | `9.079` | `9.932` | `10.785` | `4.925 mV` | `17.065 us` |

## Interpretation

The `5 us` delayed-reference switching validation supports the claim that
`T_slew` is an objective-sensitive supervisory scheduling variable.  The
`alpha=0.05` table is best for base and `0.05` settling-aware scores, while
the `alpha=0.10` table is best for the stronger settling penalty.  This is
stronger than a pure offline label table because the selected reference profile
was committed through a delayed `Iph_ref_ts` in the derived switching model.

## Boundary

This is still not neural-network AI-in-loop and not hardware/HIL.  It validates
a table-driven low-dimensional supervisory interface.  IQCOT inner-loop event
triggering is unchanged.

## Outputs

- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_table_supervisor_validation_switching_report.md`
- `E:/Desktop/codex/output/figures/fig27_table_supervisor_delayed_switching.png`
- `E:/Desktop/codex/output/iqcot_table_supervisor_delayed_switching_paper_section.md`

## Next

Run the same delayed-reference validation for `tau_AI=0.5/1/2 us`, then compare
whether the `5 us` ordering smoothly degrades or changes at smaller latencies.
