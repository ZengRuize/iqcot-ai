# E010-A5-T4-R1 Waveform Audit

Date: 2026-06-30

## Logged Signal Families

The R1 derived models log voltage, external load current, real/sensed phase currents, QH/QL gates, raw and accepted REQ, phase index, active high-side phase, Ton command/actual width, `area_int_i`, controlled reentry, burst-limiter state, area clamp, and optional Ton-ramp usage. R1 controls are inserted in projected Ton and IQCOT request-enable scheduling paths, not as direct gate commands.

## Availability Summary

- `R1-T4a`: all required candidate audit signals logged and finite.
- `R1-T4b`: all required candidate audit signals logged and finite.
- `R1-T4c`: all required candidate audit signals logged and finite.

## Wave Samples

- `R1-T4a`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_t4a_burst_limiter_40A_to_1A_wave_sample.csv`
- `R1-T4b`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_t4b_burst_area_clamp_40A_to_1A_wave_sample.csv`
- `R1-T4c`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_t4c_burst_clamp_ton_ramp_40A_to_1A_wave_sample.csv`

## Interpretation

`MODEL_REVISED`: waveform logging supports only this local fixed-four-phase severe-drop R1 comparison. All R1 candidate audit signals were available, so the severe undershoot/final-error failure is treated as model-revision evidence rather than a logging gap. Active Lambda, active-phase interaction, broad robustness, and hardware/HIL claims remain forbidden.
