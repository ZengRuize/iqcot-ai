# E030 Waveform Audit

Date: 2026-06-29

## Scope

Audit for the smallest E030 DCR-mismatch chunk: fixed `40A`, alternating DCR +/-10%, variants C0-C4.

## Required Signals

- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`
- `Ton_trim1..4`, `Lambda_trim1..4` where applicable
- `active_phase_set`, `guard_clamp_count`, `fallback_count`

## Generated Phase Trigger Tables

- `C0`: `experiments/E030_balance_recovery/e030_c0_dcr_mismatch_phase_triggers.csv`
- `C1`: `experiments/E030_balance_recovery/e030_c1_ton_diff_phase_triggers.csv`
- `C2`: `experiments/E030_balance_recovery/e030_c2_lambda_diff_phase_triggers.csv`
- `C3`: `experiments/E030_balance_recovery/e030_c3_ton_lambda_diff_phase_triggers.csv`
- `C4`: `experiments/E030_balance_recovery/e030_c4_pis_iek_projected_phase_triggers.csv`

## Structural Check Note

`model_check` on the derived C4 model retains the known inherited baseline warnings, including unused diagnostic outputs and Simscape physical-port check artifacts. The E030-specific Lambda projection input wiring issue found during development was fixed by reusing shared constant blocks instead of deleting and recreating `E030_PIS_Project_Enable`.
