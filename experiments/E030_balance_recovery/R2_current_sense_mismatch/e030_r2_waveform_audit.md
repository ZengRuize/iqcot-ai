# E030-R2 Waveform Audit

Date: 2026-06-29

## Scope

Audit for R2 current-sense mismatch: fixed `40A`, nominal DCR, current-sense gains `[1.05 0.95 1.05 0.95]`, variants R2-C0/R2-C1/R2-C4a/R2-C4c.

## Required Signals

- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`
- `IL_sense1..IL_sense4` for controller-observed current imbalance
- `Ton_trim1..4`, `ton_projection_scale` where applicable
- `active_phase_set`, `guard_clamp_count`, `fallback_count`

## REQ Count Audit

| Variant | REQ count | Dropped REQ vs C0 | Phase order error |
|---|---:|---:|---:|
| R2-C0 | 340 | 0 | 0 |
| R2-C1 | 353 | 0 | 0 |
| R2-C4a | 352 | 0 | 0 |
| R2-C4c | 353 | 0 | 0 |

## Generated Phase Trigger Tables

- `R2-C0`: `experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c0_current_sense_mismatch_phase_triggers.csv`
- `R2-C1`: `experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c1_ton_diff_reference_phase_triggers.csv`
- `R2-C4a`: `experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c4a_reduced_KT_phase_triggers.csv`
- `R2-C4c`: `experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_c4c_voltage_aware_phase_triggers.csv`

## Lambda Boundary

R2 does not implement active Lambda actuation. No active Lambda claim is allowed from this run.
