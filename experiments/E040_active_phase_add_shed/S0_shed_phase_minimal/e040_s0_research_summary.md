# E040-S0 Minimal Shed-Phase Summary

Date: 2026-06-30

## Scope

Local derived-Simulink validation for `40A -> 20A`, `4 -> 2` active-phase shed only. Baseline source: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`.

## Design Under Test

Four-phase events are preserved before shed. After shed, accepted events are remapped onto physical phases `[1,3]`. S3 gates shed by dwell, post-reentry delay, residual-current threshold, order relock, and delayed a_S enable. Active Lambda remains disabled.

## Metrics CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_metrics.csv`

| Variant | Success | N init | N final | Shed accept | Overshoot mV | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| S0 | 1 | 4 | 4 | 0 | 1.13166 | 0.45125 | 0.698733 | NaN | NaN | NaN | NaN | 0 | 0 | NaN | fixed_four_phase_reference |
| S1 | 1 | 4 | 2 | 1 | 0.944587 | 663.614 | -624.357 | 14.6727 | 8.91282 | 0 | 0 | 0 | 0 | NaN | current_limit_hit |
| S2 | 1 | 4 | 2 | 12 | 1.48593 | 543.833 | -500.714 | 9.58001 | 4.01163 | 1 | 0.265152 | 0 | 0 | NaN | current_limit_hit |
| S3 | 1 | 4 | 3.79065 | 34 | 1.48593 | 19.1326 | -3.37124 | 9.58001 | 4.01163 | 1 | 0.992308 | 0 | 0 | 6.792 | shed_not_accepted |

## Interpretation

- `S0`: N_final `4`, shed_accept `0`, dropped_REQ `0`, inactive_REQ `0`, residual_pass `NaN`, post_order_error `NaN`, hint `fixed_four_phase_reference`.
- `S1`: N_final `2`, shed_accept `1`, dropped_REQ `0`, inactive_REQ `0`, residual_pass `0`, post_order_error `0`, hint `current_limit_hit`.
- `S2`: N_final `2`, shed_accept `12`, dropped_REQ `0`, inactive_REQ `0`, residual_pass `1`, post_order_error `0.265152`, hint `current_limit_hit`.
- `S3`: N_final `3.79065`, shed_accept `34`, dropped_REQ `0`, inactive_REQ `0`, residual_pass `1`, post_order_error `0.992308`, hint `shed_not_accepted`.

## Classification

`MODEL_REVISED`

At least one shed transition occurred, but the guarded S3 minimum pass criteria were not all satisfied.

## Claim Boundary

S0 does not yet support broad shed claims. Active-phase shedding still requires revised lockout, residual-current qualification, order relock, or recovery gating before expansion.

Forbidden claims remain: broad active-phase robustness, arbitrary 1/2/4 scheduling, severe shed behavior, active Lambda, efficiency gain, hardware, HIL, board-level, or silicon validation.
