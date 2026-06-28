# E010 A2 Ton-Truncation Plus Pulse-Inhibit Small Chunk

Date: 2026-06-28

## Hypothesis

A2 tests whether deterministic Ton truncation plus early event-domain pulse inhibit reduces load-drop overshoot for an external `40A -> 20A` load-current disturbance. The inhibit block applies a short combinational time-window gate to scheduled COT triggers only; it does not command QH/QL gates or the load current.

Action-token parameters:

```text
Tton_trunc_min = 80 ns
Tton_trunc_window = 2 us
pulse_inhibit_count_guard = 1
inhibit_time = 1.8 us
```

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A2_ton_trunc_pulse_inhibit_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a2_40A_to_20A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a2_40A_to_20A_wave_sample.csv`

## Observability

The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and pulse-inhibit logging. A2 inserts deterministic supervisory event logic before COT cell requests and Ton truncation before COT Ton inputs; no gate command or load-current command is directly controlled.

## Metrics

| Metric | Value |
|---|---:|
| peak overshoot mV | 1.1607 |
| early local peak 0-2us mV | 0.306928 |
| recovery peak 2-12us mV | -3.49921 |
| late settling 12-80us abs mV | 3.70689 |
| undershoot penalty mV | 8.51044 |
| skip count estimate | 0 |
| final error mV | 0.691301 |
| phase current peak A | 14.8178 |
| Ton actual peak ns | 200 |
| Ton trunc command peak ns | 196.5 |
| Ton trunc active fraction | 0.394488 |
| pulse inhibit active fraction | 0.00019685 |
| pulse inhibit event estimate | 1 |

## Classification

`MODEL_CONFIRMED`: the derived A2 model ran and produced first-pass Ton-truncation plus pulse-inhibit metrics. The result must be compared against A0/A1 before claiming improvement.
