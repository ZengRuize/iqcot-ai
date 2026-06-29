# E040-A Waveform Audit

Date: 2026-06-29

## Scope

Audit for the minimal E040-A add-phase chunk: `20A -> 40A`, `2 -> 4` active phases, D0/D1/D2/D3, nominal sensing, active Lambda disabled.

## Required Signal Status

All variants produced metric rows with required voltage, current, REQ, phase, Ton, active-phase, guard, and selector logs.

| Variant | Success | N initial | N final | Add accepts | Dropped REQ | Phase-order error | Hint |
|---|---:|---:|---:|---:|---:|---:|---|
| D0 | 1 | 2 | 2 | 0 | 0 | 0.142857 | fixed_two_phase_reference |
| D1 | 1 | 2 | 4 | 1 | 0 | 0.120482 | phase_order_error |
| D2 | 1 | 2 | 4 | 1 | 0 | 0.170732 | phase_order_error |
| D3 | 1 | 2 | 4 | 1 | 0 | 0.170732 | phase_order_error |

## Generated Wave Samples

- `D0`: `experiments/E040_active_phase_add_shed/e040_d0_fixed_two_phase_wave_sample.csv`
- `D1`: `experiments/E040_active_phase_add_shed/e040_d1_immediate_add_wave_sample.csv`
- `D2`: `experiments/E040_active_phase_add_shed/e040_d2_guarded_add_as_wave_sample.csv`
- `D3`: `experiments/E040_active_phase_add_shed/e040_d3_guarded_add_confidence_wave_sample.csv`

## Lambda Boundary

Active Lambda control is disabled. `Lambda_trim_usage` must remain zero; any Lambda signal is audit-only.

## Model-Check Boundary

`model_check` was run on the final D3 derived copy:

```text
E:/Desktop/codex/models/derived/E040A_D3_guard_add_conf_iqcot_20260629.slx
```

It reported the same inherited baseline pattern as the original ideal IQCOT model: 7 unconnected Add/OnDelay errors and 33 warnings for diagnostic outputs / Simscape physical-port check artifacts. No additional E040-specific active-phase supervisor, `REQ`, Ton, or current-sense wiring issue was identified by this structural check.

## Classification

`MODEL_REVISED`
