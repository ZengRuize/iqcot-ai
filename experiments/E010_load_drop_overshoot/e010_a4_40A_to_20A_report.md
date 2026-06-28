# E010 A4 AI/Table-Selected a_O Small Chunk

Date: 2026-06-28

## Hypothesis

A4 tests the table-selected load-drop `a_O` token under a simple safety projection for an external `40A -> 20A` disturbance. The selection rule is: choose no-op for mild load drops, otherwise accept only candidates with projected undershoot penalty at or below `1 mV`, then minimize recovery peak and late settling. The load-current step remains an external disturbance.

Selected `a_O` parameters:

```text
protect_level_down = noop_for_mild_load_drop
active_HS_trunc_enable = 0
Tton_trunc_min = 0 ns
Tton_trunc_window = 0 us
pulse_inhibit_count_guard = 0
inhibit_time = 0 us
reentry_band_down = 0 mV
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A4_ai_table_aO_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a4_40A_to_20A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a4_40A_to_20A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and guarded pulse-inhibit logging. A4 applies a table-selected supervisory token after safety projection; no gate command or load-current command is directly controlled.

## Metrics

| Metric | Value |
|---|---:|
| peak overshoot mV | 1.13166 |
| early local peak 0-2us mV | 0.515663 |
| recovery peak 2-12us mV | 1.09036 |
| late settling 12-80us abs mV | 1.13166 |
| undershoot penalty mV | 0.45125 |
| skip count estimate | 0 |
| final error mV | 0.700474 |
| phase current peak A | 14.6727 |
| Ton actual peak ns | 200 |
| Ton trunc command peak ns | 196.5 |
| Ton trunc active fraction | 0 |
| pulse inhibit active fraction | 0 |
| pulse inhibit event estimate | 0 |

## Classification

`MODEL_CONFIRMED`: the derived A4 model ran the table-selected load-drop a_O token under a 1 mV undershoot safety constraint and load-drop magnitude selector.
