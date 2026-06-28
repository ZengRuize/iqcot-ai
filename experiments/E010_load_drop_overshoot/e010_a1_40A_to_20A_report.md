# E010 A1 Ton-Truncation Small Chunk

Date: 2026-06-28

## Hypothesis

A1 tests whether Ton truncation alone reduces load-drop overshoot for an external `40A -> 20A` load-current disturbance. The load current remains an external test profile, not an AI command.

Ton truncation parameters:

```text
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A1_ton_trunc_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a1_40A_to_20A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a1_40A_to_20A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, and `Ton_cmd_trunc1..4` logging. A1 inserts only a deterministic Ton-truncation block between the IQCOT Ton adapter and each COT cell; no AI/table action and no load-current command are applied.

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
| pulse inhibit active fraction | NaN |
| pulse inhibit event estimate | NaN |

## Classification

`MODEL_CONFIRMED`: the derived A1 model ran and produced first-pass Ton-truncation metrics. The result must be compared against A0 before claiming improvement.
