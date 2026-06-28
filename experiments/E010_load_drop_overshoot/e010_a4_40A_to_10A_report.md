# E010 A4 AI/Table-Selected a_O Small Chunk

Date: 2026-06-28

## Hypothesis

A4 tests the table-selected load-drop `a_O` token under a simple safety projection. The selection rule for this first chunk is: among A1/A2/A3-style candidates, accept only candidates with projected undershoot penalty at or below `1 mV`, then minimize recovery peak and late settling. The load-current step remains an external disturbance.

Selected `a_O` parameters:

```text
protect_level_down = table_selected_level_1
active_HS_trunc_enable = 1
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
pulse_inhibit_count_guard = 1
inhibit_time = 1.8 us
reentry_band_down = 1 mV
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A4_ai_table_aO_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a4_40A_to_10A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a4_40A_to_10A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and guarded pulse-inhibit logging. A4 applies a table-selected supervisory token after safety projection; no gate command or load-current command is directly controlled.

## Metrics

| Metric | Value |
|---|---:|
| peak overshoot mV | 2.35886 |
| early local peak 0-2us mV | 1.98475 |
| recovery peak 2-12us mV | 1.84342 |
| late settling 12-80us abs mV | 2.33816 |
| undershoot penalty mV | 0.863951 |
| skip count estimate | 1 |
| final error mV | 1.85155 |
| phase current peak A | 14.6727 |
| Ton actual peak ns | 200 |
| Ton trunc command peak ns | 196.5 |
| Ton trunc active fraction | 0.39425 |
| pulse inhibit active fraction | 9.8464e-05 |
| pulse inhibit event estimate | 1 |

## Classification

`MODEL_CONFIRMED`: the derived A4 model ran the table-selected load-drop a_O token under a 1 mV undershoot safety constraint.
