# E020 Waveform Audit

Date: 2026-06-29

## Scope

Audit for the smallest E020 load-rise chunk: external `40A -> 120A`, variants B0/B1/B2/B3.

## Required Signals

- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`
- `Lambda_i`, `area_int_i`, `active_phase_set`
- E020 action logs where applicable: `fast_request_active`, `ton_boost_active1..4`, `Ton_cmd_boost1..4`

## Generated Wave Samples

- `B0`: `experiments/E020_load_rise_undershoot/e020_b0_40A_to_120A_wave_sample.csv`
- `B1`: `experiments/E020_load_rise_undershoot/e020_b1_40A_to_120A_wave_sample.csv`
- `B2`: `experiments/E020_load_rise_undershoot/e020_b2_40A_to_120A_wave_sample.csv`
- `B3`: `experiments/E020_load_rise_undershoot/e020_b3_40A_to_120A_wave_sample.csv`

## Audit Notes

All variants produced metric rows. Inspect wave samples around `0-3 us` for the first current-ramp response and `3-80 us` for recovery overshoot/settling.

## Structural Check

`model_check` on B3 reported the same 7 errors and 33 warnings as the unmodified baseline and B0 derived copy. These are inherited unused top-level Add/OnDelay ports, unconnected diagnostic outputs, and Simscape physical-port check artifacts from the baseline; they are not newly introduced by the E020 fast-request or Ton-boost wiring.

The E020-specific validation therefore relies on:

- successful simulation for B0/B1/B2/B3;
- successful logging of required metrics;
- matching baseline/B0/B3 structural-check issue pattern.
