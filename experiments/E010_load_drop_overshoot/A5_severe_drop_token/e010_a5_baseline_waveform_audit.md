# E010-A5 Baseline Waveform Audit

Date: 2026-06-30

## Logged Signal Families

The A5-C0/A5-C4 derived models log voltage, external load current, real/sensed phase currents, QH/QL gates, raw and accepted REQ, phase index, active high-side phase, Ton command/actual width, `Lambda_i`, `area_int_i`, and passive A5 state placeholders. These placeholders do not affect IQCOT behavior and do not validate A5.

## Availability Summary

- `A5-C0`: all required audit signals logged and finite.
- `A5-C4`: all required audit signals logged and finite.

## Wave Samples

- `A5-C0`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_c0_baseline_40A_to_1A_wave_sample.csv`
- `A5-C4`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_c4_previous_A4_40A_to_1A_wave_sample.csv`

## Interpretation

`MODEL_CONFIRMED`: waveform logging is an infrastructure result only. A5 severe-drop improvement, active-phase interaction, active Lambda control, and hardware/HIL claims remain forbidden.
