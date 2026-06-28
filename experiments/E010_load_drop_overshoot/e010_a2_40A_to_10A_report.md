# E010 A2 Ton-Truncation Plus Pulse-Inhibit Small Chunk

Date: 2026-06-28

## Hypothesis

A2 tests whether deterministic Ton truncation plus early event-domain pulse inhibit reduces load-drop overshoot for an external `40A -> 10A` load-current disturbance. The inhibit block applies a short combinational time-window gate to scheduled COT triggers only; it does not command QH/QL gates or the load current.

Action-token parameters:

```text
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
pulse_inhibit_count_guard = 1
inhibit_time = 1.8 us
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A2_ton_trunc_pulse_inhibit_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a2_40A_to_10A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a2_40A_to_10A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and pulse-inhibit logging. A2 inserts deterministic supervisory event logic before COT cell requests and Ton truncation before COT Ton inputs; no gate command or load-current command is directly controlled.

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

`MODEL_CONFIRMED`: the derived A2 model ran and produced first-pass Ton-truncation plus pulse-inhibit metrics. The result must be compared against A0/A1 before claiming improvement.
