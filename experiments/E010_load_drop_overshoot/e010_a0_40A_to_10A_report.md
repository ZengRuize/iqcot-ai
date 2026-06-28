# E010 A0 Load-Drop Small Chunk

Date: 2026-06-28

## Hypothesis

A0 measures the original ideal IQCOT response to an external `40A -> 10A` load-current disturbance. No AI/table action is applied, and the load current is not an AI command.

## Paths

- Derived model: `E:/Desktop/codex/models/derived/E010_A0_load_drop_observable_from_ideal_iqcot_20260628.slx`
- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a0_40A_to_10A_metrics.csv`
- Wave sample CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a0_40A_to_10A_wave_sample.csv`

## Observability

The derived model adds observability only: external `Iload`, fixed-four-phase `active_phase_set`, and `Ton_actual1..4` pulse-width estimates. The baseline IQCOT request path is not protected, boosted, truncated, or AI scheduled in A0.

## Metrics

| Metric | Value |
|---|---:|
| peak overshoot mV | 2.37866 |
| early local peak 0-2us mV | 1.98475 |
| recovery peak 2-12us mV | 2.36936 |
| late settling 12-80us abs mV | 2.37866 |
| undershoot penalty mV | 0 |
| skip count estimate | 1 |
| final error mV | 1.83447 |
| phase current peak A | 14.6727 |
| Ton actual peak ns | 200 |

## Classification

`MODEL_CONFIRMED`: the derived A0 model ran and produced the required first-pass E010 metrics. This confirms measurability of the baseline branch, not improvement.
