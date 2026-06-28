# E010 A3 Guarded-Reentry Small Chunk

Date: 2026-06-28

## Hypothesis

A3 tests the same Ton truncation and early event-domain pulse inhibit as A2, but applies a model-based reentry projection for an external `40A -> 20A` disturbance: inhibit is allowed only while `Vout >= Vref + reentry_band_down`. The load current remains an external disturbance.

Action-token and projection parameters:

```text
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
pulse_inhibit_count_guard = 1
inhibit_time = 1.8 us
reentry_band_down = 1.2 mV
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A3_guarded_reentry_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a3_40A_to_20A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a3_40A_to_20A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and guarded pulse-inhibit logging. A3 inserts deterministic supervisory event logic plus a voltage reentry guard before COT cell requests; no gate command or load-current command is directly controlled.

## Metrics

| Metric | Value |
|---|---:|
| peak overshoot mV | 1.18091 |
| early local peak 0-2us mV | 0.306928 |
| recovery peak 2-12us mV | 1.11391 |
| late settling 12-80us abs mV | 1.18091 |
| undershoot penalty mV | 3.58972 |
| skip count estimate | 1 |
| final error mV | 0.70114 |
| phase current peak A | 14.6727 |
| Ton actual peak ns | 200 |
| Ton trunc command peak ns | 196.5 |
| Ton trunc active fraction | 0.396389 |
| pulse inhibit active fraction | 0 |
| pulse inhibit event estimate | 0 |

## Classification

`MODEL_CONFIRMED`: the derived A3 model ran and produced first-pass guarded-reentry metrics. The result must be compared against A0/A1/A2 before claiming improvement.
