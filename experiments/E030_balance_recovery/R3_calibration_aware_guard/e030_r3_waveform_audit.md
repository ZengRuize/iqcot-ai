# E030-R3 Waveform Audit

Date: 2026-06-29

## Scope

Audit for R3 calibration-aware guard: fixed `40A`, nominal DCR, current-sense gains `[1.05 0.95 1.05 0.95]`, variants R3-C0/R3-C1low/R3-C4a_conf/R3-C4a_cal/R3-C4c_cal.

## Required Signals

- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`
- `IL_sense1..IL_sense4` for controller-observed current imbalance
- `IL_est1..IL_est4` for calibration-aware current estimate
- `Ton_trim1..4`, `ton_projection_scale` where applicable
- `active_phase_set`, `guard_clamp_count`, `fallback_count`

## REQ Count Audit

| Variant | REQ count | Dropped REQ vs C0 | Phase order error |
|---|---:|---:|---:|
| R3-C0 | 340 | 0 | 0 |
| R3-C1low | 340 | 0 | 0 |
| R3-C4a_conf | 340 | 0 | 0 |
| R3-C4a_cal | 352 | 0 | 0 |
| R3-C4c_cal | 353 | 0 | 0 |

## Generated Phase Trigger Tables

- `R3-C0`: `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c0_current_sense_mismatch_phase_triggers.csv`
- `R3-C1low`: `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c1low_low_gain_fallback_phase_triggers.csv`
- `R3-C4a_conf`: `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c4a_confidence_gated_phase_triggers.csv`
- `R3-C4a_cal`: `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c4a_ideal_calibrated_phase_triggers.csv`
- `R3-C4c_cal`: `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_c4c_ideal_calibrated_phase_triggers.csv`

## Lambda Boundary

R3 does not implement active Lambda actuation. No active Lambda claim is allowed from this run.

## Model-Check Boundary

Simulink `model_check` was run on R3-C0, R3-C4a_conf, and R3-C4a_cal. The reported unconnected Add/OnDelay/COT diagnostic/Simscape measurement items match the known inherited baseline diagnostics; no R3-specific IL_sense, IL_est, or Ton-projector wiring issue was observed.
