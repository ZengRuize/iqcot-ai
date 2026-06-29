# E020 Load-Rise Undershoot Research Summary

Date: 2026-06-29

## Hypothesis

For an external `40A -> 120A` load-current rise, the inductor-current sum initially lags the new load demand, so `Cout` supplies deficit current and `Vout` undershoots. The load-rise branch should add energy using guarded scheduler requests and/or bounded Ton boost. It must not use load-drop Ton truncation or pulse inhibit.

## Model Copy Path

- `B0`: `E:/Desktop/codex/models/derived/E020_B0_load_rise_observable_from_ideal_iqcot_20260629.slx`
- `B1`: `E:/Desktop/codex/models/derived/E020_B1_fast_request_from_ideal_iqcot_20260629.slx`
- `B2`: `E:/Desktop/codex/models/derived/E020_B2_ton_boost_from_ideal_iqcot_20260629.slx`
- `B3`: `E:/Desktop/codex/models/derived/E020_B3_fast_request_ton_boost_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Modified Blocks/Signals

- B0: observability only in a derived copy.
- B1: guarded fast scheduler trigger projection before the global `tr` event.
- B2: bounded Ton boost between `IQCOT_Ton_Adapter` and the COT cells.
- B3: B1 and B2 combined.
- All variants keep the external load-current profile as a validation input, not an AI command.

## External Load Profile

`40A -> 120A` at `450 us`.

## Controller Variants Compared

`B0`, `B1`, `B2`, `B3`.

## Metrics Table

Metrics CSV: `E:/Desktop/codex/experiments/E020_load_rise_undershoot/e020_metrics.csv`

| Variant | Success | Peak undershoot mV | Current rise us | Recovery overshoot mV | Phase current peak A | Current limit hit | Settling us | Final error mV | Events 0-2us | Ton boost usage | Fast request count |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| B0 | 1 | 397.42 | 37.996 | -8.86316 | 34.0379 | 0 | NaN | -376.361 | 4 | 0 | 0 |
| B1 | 1 | 343.787 | 2.658 | -8.86316 | 33.9041 | 0 | NaN | -322.051 | 10 | 0 | 19 |
| B2 | 1 | 382.408 | 39.92 | -8.86316 | 33.8865 | 0 | NaN | -362.688 | 4 | 0.99935 | 0 |
| B3 | 1 | 319.081 | 1.212 | -8.86316 | 34.0934 | 0 | NaN | -297.928 | 9 | 0.999356 | 19 |

## Waveform Interpretation

B0 peak undershoot is `397.42 mV`. Differences below are reductions relative to B0:

| Variant | Undershoot reduction mV | Current peak delta A | Recovery overshoot delta mV |
|---|---:|---:|---:|
| B1 | 53.633 | -0.13382 | 0 |
| B2 | 15.0122 | -0.151444 | 0 |
| B3 | 78.3387 | 0.0555294 | 0 |

Boundary interpretation:

```text
B3 confirms peak-undershoot reduction and current-rise acceleration.
B3 does not confirm complete recovery in the simulated window.
B3 final error at 75-90us remains about -297.93 mV.
No tested variant settled within the 1 mV band in the 90us post-step window.
```

## Failure Or Trade-Off Analysis

At least one projected a_U component reduced peak undershoot without violating the phase-current guard or recovery-overshoot budget.

## Classification

`MODEL_CONFIRMED`

## Theory Documents Updated

Updated:

- `docs/theory/02_bidirectional_large_signal_model.md`
- `docs/theory/04_ai_action_space_and_projection.md`
- `docs/theory/06_claim_boundaries.md`
- `docs/theory/07_e020_load_rise_derivation.md`

## Claim Boundary Updated

E020 is derived-Simulink evidence only. It is not hardware, HIL, board-level, or silicon evidence. The allowed claim is limited to local peak-undershoot reduction and current-rise acceleration for the first `40A -> 120A` chunk.

## Next Smallest Useful Experiment

Tune the winning a_U window, then test `20A -> 120A` or `10A -> 40A` before phase-add.
