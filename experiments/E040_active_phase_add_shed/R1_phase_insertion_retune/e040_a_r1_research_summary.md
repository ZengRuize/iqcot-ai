# E040-A-R1 Phase-Insertion Retune Summary

Date: 2026-06-29

## Scope

Local derived-Simulink validation for `20A -> 40A`, `2 -> 4` active-phase add only. Baseline source: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`.

## Design Under Test

Two-phase events are remapped onto physical phases `[1,3]`; after add/relock, accepted events use `[1,2,3,4]`. Frozen guarded `a_S` is enabled only after add, ramp, order relock, and reentry delay in R1-D3. Active Lambda remains disabled.

## Metrics CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv`

| Variant | Success | N init | N final | Add accept | Under mV | Final err mV | Real imb A | Post order err | Dropped REQ | Inactive REQ | Current limit | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-D0 | 1 | 2 | 2 | 0 | 907.223 | -903.504 | 0.170176 | 0 | 0 | 0 | 0 | NaN | fixed_two_phase_reference |
| R1-D1 | 1 | 2 | 4 | 1 | 801.96 | -270.375 | 0.245432 | 0 | 0 | 0 | 0 | NaN | local_add_integrity_pass |
| R1-D2 | 1 | 2 | 4 | 1 | 807.856 | -334.944 | 0.996605 | 0 | 0 | 0 | 0 | NaN | local_add_integrity_pass |
| R1-D3 | 1 | 2 | 4 | 1 | 807.856 | -340.265 | 0.846972 | 0 | 0 | 0 | 0 | 5.5 | local_add_integrity_pass |

## Interpretation

- `R1-D0`: N_final `2`, add_accept `0`, dropped_REQ `0`, inactive_REQ `0`, post_order_error `0`, hint `fixed_two_phase_reference`.
- `R1-D1`: N_final `4`, add_accept `1`, dropped_REQ `0`, inactive_REQ `0`, post_order_error `0`, hint `local_add_integrity_pass`.
- `R1-D2`: N_final `4`, add_accept `1`, dropped_REQ `0`, inactive_REQ `0`, post_order_error `0`, hint `local_add_integrity_pass`.
- `R1-D3`: N_final `4`, add_accept `1`, dropped_REQ `0`, inactive_REQ `0`, post_order_error `0`, hint `local_add_integrity_pass`.

## Classification

`MODEL_CONFIRMED`

Corrected remap/insertion/relock preserved local 2->4 add integrity and improved voltage recovery versus the fixed two-phase reference.

## Claim Boundary

Allowed claim: in the local ideal IQCOT derived model, corrected active-phase remap plus guarded insertion/relock enables the moderate `20A -> 40A`, `2 -> 4` add transition while preserving REQ integrity and post-add phase order. This remains Simulink-only evidence.

Forbidden claims remain: broad active-phase robustness, shed behavior, active Lambda, severe load-rise/drop performance, efficiency gain, hardware, HIL, board-level, or silicon validation.
