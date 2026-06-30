# E010-A5-R2 Waveform Audit

Date: 2026-07-01

## Availability

- `R2-E1`: all required R2 audit signals logged and finite.
- `R2-E2`: all required R2 audit signals logged and finite.
- `R2-E3`: all required R2 audit signals logged and finite.
- `R2-E4`: all required R2 audit signals logged and finite.

## Wave Samples

- `R2-E1`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_e1_energy_ton_ramp_40A_to_1A_wave_sample.csv`
- `R2-E2`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_e2_energy_area_preload_40A_to_1A_wave_sample.csv`
- `R2-E3`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_e3_scheduler_release_40A_to_1A_wave_sample.csv`
- `R2-E4`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_e4_voltage_window_release_40A_to_1A_wave_sample.csv`

## Interpretation

`MODEL_REVISED`: waveform evidence is local derived-Simulink evidence only. It is not hardware, HIL, board, or silicon validation.

E1/E2 show real positive-peak reduction but fail the undershoot and burst guards. E3/E4 show that the current scheduler release gate can starve recovery energy; zero positive peak is therefore not an improvement when it is paired with severe undershoot and final-error collapse.
