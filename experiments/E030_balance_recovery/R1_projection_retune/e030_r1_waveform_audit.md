# E030-R1 Waveform Audit

Date: 2026-06-29

## Scope

Audit for R1 projection retune: fixed `40A`, alternating DCR +/-10%, variants R1-C0/R1-C1/R1-C4a-d.

## Required Signals

- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`
- `Ton_trim1..4`, `ton_projection_scale` where applicable
- `active_phase_set`, `guard_clamp_count`, `fallback_count`

## REQ Count Audit

| Variant | REQ count | Dropped REQ vs C0 | Phase order error |
|---|---:|---:|---:|
| R1-C0 | 339 | 0 | 0 |
| R1-C1 | 353 | 0 | 0 |
| R1-C4a | 353 | 0 | 0 |
| R1-C4b | 353 | 0 | 0 |
| R1-C4c | 353 | 0 | 0 |
| R1-C4d | 353 | 0 | 0 |

## Generated Phase Trigger Tables

- `R1-C0`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c0_dcr_mismatch_phase_triggers.csv`
- `R1-C1`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c1_ton_diff_reference_phase_triggers.csv`
- `R1-C4a`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4a_reduced_KT_phase_triggers.csv`
- `R1-C4b`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4b_reduced_Ttrim_phase_triggers.csv`
- `R1-C4c`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4c_voltage_aware_phase_triggers.csv`
- `R1-C4d`: `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_c4d_ripple_phase_aware_phase_triggers.csv`

## Lambda Boundary

R1 does not implement active Lambda actuation. No active Lambda claim is allowed from this run.
