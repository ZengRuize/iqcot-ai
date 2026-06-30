# E040-S1 Staged Shed-Handoff Summary

Date: 2026-06-30

## Scope

Local derived-Simulink preflight for `40A -> 20A`, `4 -> 2` active-phase shed only. The baseline source is `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx` and is not modified.

## Baseline Audit

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_baseline_wiring_audit.md`

## Metrics CSV

`E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv`

| Variant | Success | N init | N final | Active final | Commit | Fallback | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | Hint |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| S1-R0 | 1 | 4 | 4 | 1111 | 0 | 0 | 0.45125 | 0.698733 | 3.68592 | 9.25788 | fail | NaN | 0 | 0 | fixed_four_phase_reference |
| S1-R2 | 1 | 4 | 4 | 1111 | 0 | 0 | 0.641487 | 2.80462 | 9.99757e-05 | 9.99756e-05 | pass | NaN | 0 | 0 | transfer_drain_interpretable |
| S1-R3 | 1 | 4 | 2 | 1010 | 1 | 0 | 0.641487 | 1.65264 | 9.99757e-05 | 9.99756e-05 | pass | 0 | 0 | 0 | local_staged_shed_integrity_pass |

## Interpretation

- `S1-R0`: success `1`, N_final `4`, active_set `1111`, commit_count `0`, fallback_count `0`, dropped_REQ `0`, inactive_REQ `0`, residual `fail`, hint `fixed_four_phase_reference`.
- `S1-R2`: success `1`, N_final `4`, active_set `1111`, commit_count `0`, fallback_count `0`, dropped_REQ `0`, inactive_REQ `0`, residual `pass`, hint `transfer_drain_interpretable`.
- `S1-R3`: success `1`, N_final `2`, active_set `1010`, commit_count `1`, fallback_count `0`, dropped_REQ `0`, inactive_REQ `0`, residual `pass`, hint `local_staged_shed_integrity_pass`.

## Classification

`MODEL_CONFIRMED`

The local 40A->20A staged shed reached exact two-phase operation with REQ integrity, residual qualification, no fallback, and bounded voltage/current behavior.

## Claim Boundary

Allowed local claim: in the local ideal IQCOT derived model, staged load-share transfer, disabled-phase drain, atomic commit, and two-phase relock enable the tested `40A -> 20A`, `4 -> 2` handoff while preserving REQ integrity and residual-current qualification. This remains Simulink-only evidence.

Forbidden claims remain: broad active-phase robustness, arbitrary 1/2/4 scheduling, severe shed behavior, active Lambda control, efficiency gain, hardware, HIL, board-level, or silicon validation.
