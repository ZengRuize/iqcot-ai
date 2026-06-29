# E040-A-R1 Waveform And Scheduler Audit

Date: 2026-06-29

## Signal Boundary

The run requires `Vout`, `Iload`, `IL1..4`, `IL_sense1..4`, `REQ_raw1..4`, `REQ_accept1..4`, `QH1..4`, `QL1..4`, `phase_idx`, `logical_slot`, `physical_phase_selected`, `active_phase_set`, `N_active`, Ton/a_S guard logs, and current-limit guard logs.

All variants produced metric rows and per-variant scheduler audit CSV files.

## Model-Check Boundary

Before simulation, `model_check` was run on the local baseline and the R1-D0 derived copy:

```text
baseline: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
derived: E:/Desktop/codex/models/derived/E040R1_D0_fixed13_iqcot_20260629.slx
result: 7 errors / 33 warnings for both
```

The reported issues match the inherited baseline diagnostics already observed in earlier E020/E030 runs: unused top-level Add/OnDelay ports, COT diagnostic outputs, and Simscape/measurement physical-port audit artifacts. No R1-specific Stateflow lint or additional unconnected-port issue was observed in this check.

## Metrics Snapshot

| Variant | Success | N init | N final | Add accept | Under mV | Final err mV | Real imb A | Post order err | Dropped REQ | Inactive REQ | Current limit | a_S us | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-D0 | 1 | 2 | 2 | 0 | 907.223 | -903.504 | 0.170176 | 0 | 0 | 0 | 0 | NaN | fixed_two_phase_reference |
| R1-D1 | 1 | 2 | 4 | 1 | 801.96 | -270.375 | 0.245432 | 0 | 0 | 0 | 0 | NaN | local_add_integrity_pass |
| R1-D2 | 1 | 2 | 4 | 1 | 807.856 | -334.944 | 0.996605 | 0 | 0 | 0 | 0 | NaN | local_add_integrity_pass |
| R1-D3 | 1 | 2 | 4 | 1 | 807.856 | -340.265 | 0.846972 | 0 | 0 | 0 | 0 | 5.5 | local_add_integrity_pass |

## Scheduler Audit Files

- `R1-D0`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d0_fixed13_scheduler_audit.csv`
- `R1-D1`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d1_remap_add_scheduler_audit.csv`
- `R1-D2`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d2_guard_relock_scheduler_audit.csv`
- `R1-D3`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d3_guard_as_scheduler_audit.csv`

## Wave Samples

- `R1-D0`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d0_fixed13_wave_sample.csv`
- `R1-D1`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d1_remap_add_wave_sample.csv`
- `R1-D2`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d2_guard_relock_wave_sample.csv`
- `R1-D3`: `E:/Desktop/codex/experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_d3_guard_as_wave_sample.csv`

## Classification

`MODEL_CONFIRMED`
