# E040-S1 Waveform And Scheduler Audit

Date: 2026-06-30

## Signal Boundary

The derived models log voltage, load, inductor currents, gate commands, raw/accepted REQ, active-phase state, staged shed state, commit/fallback flags, residual-current guards, order relock, Ton trim, and Lambda usage. Per-phase Ton command logs are exported as `Ton_cmd1..4`; active Lambda remains disabled and `Lambda_trim_usage` must stay zero.

## Required Audit Table

Each per-variant scheduler audit CSV uses columns: `event_index`, `time_us`, `shed_state`, `active_phase_set`, `N_active`, `logical_slot`, `physical_phase_selected`, `REQ_in_phase`, `REQ_accept_phase`, `REQ_reject_reason`, `phase_idx_before`, `phase_idx_after`, `commit_armed`, `commit_done`, `fallback_4ph_triggered`, `fallback_reason`.

## Per-Variant Files

- `S1-R0`: scheduler `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_scheduler_audit.csv`, signals `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_signal_availability.csv`, wave `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r0_fixed4_wave_sample.csv`
- `S1-R2`: scheduler `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r2_transfer_drain_scheduler_audit.csv`, signals `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r2_transfer_drain_signal_availability.csv`, wave `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r2_transfer_drain_wave_sample.csv`
- `S1-R3`: scheduler `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r3_commit_relock_scheduler_audit.csv`, signals `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r3_commit_relock_signal_availability.csv`, wave `E:/Desktop/codex/experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_r3_commit_relock_wave_sample.csv`

## Metrics Snapshot

| Variant | Success | N init | N final | Active final | Commit | Fallback | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | Hint |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| S1-R0 | 1 | 4 | 4 | 1111 | 0 | 0 | 0.45125 | 0.698733 | 3.68592 | 9.25788 | fail | NaN | 0 | 0 | fixed_four_phase_reference |
| S1-R2 | 1 | 4 | 4 | 1111 | 0 | 0 | 0.641487 | 2.80462 | 9.99757e-05 | 9.99756e-05 | pass | NaN | 0 | 0 | transfer_drain_interpretable |
| S1-R3 | 1 | 4 | 2 | 1010 | 1 | 0 | 0.641487 | 1.65264 | 9.99757e-05 | 9.99756e-05 | pass | 0 | 0 | 0 | local_staged_shed_integrity_pass |

## Classification

`MODEL_CONFIRMED`

## Missing Signal Rule

Unavailable signals are recorded in each `*_signal_availability.csv`. Metrics are not fabricated when a signal is unavailable; failed collection is classified as `IMPLEMENTATION_ISSUE`.
