# E020 B0 Load-Rise Baseline

Date: 2026-06-29

## Hypothesis

This run evaluates an external `40A -> 120A` load-current rise. The controller branch must add energy; it must not use load-drop Ton truncation or pulse inhibit. The AI/table layer is represented only by projected low-dimensional parameters and does not command load slew or gate signals.

## Model Copy Path

`E:/Desktop/codex/models/derived/E020_B0_load_rise_observable_from_ideal_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Modified Blocks/Signals

- Replaced static load with `E020_Load_Current_Source` driven by external `Iload` step.
- Added logs for `Iload`, `active_phase_set`, `Ton_cmd1..4`, `Ton_actual1..4`, `REQ1..4`, `phase_idx`, `Lambda_i`, and `area_int_i`.

## External Load Profile

`40A -> 120A` at `450 us`.

## Controller Variant

`B0_original_ideal_iqcot_observable`

## Metrics

| Variant | Success | Peak undershoot mV | Current rise us | Recovery overshoot mV | Phase current peak A | Current limit hit | Settling us | Final error mV | Events 0-2us | Ton boost usage | Fast request count |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| B0 | 1 | 397.42 | 37.996 | -8.86316 | 34.0379 | 0 | NaN | -376.361 | 4 | 0 | 0 |

## Waveform Interpretation

Interpretation is consolidated in `e020_research_summary.md` after B0/B1/B2/B3 are compared.

## Failure Or Trade-Off Analysis

Current-limit guard: `55 A/phase`; undershoot action band: `0.2 mV`.

## Classification

Per-run status: executable. Final E020 classification is assigned in `e020_research_summary.md` after all variants are compared.

## Theory Documents Updated

Pending final E020 classification.

## Claim Boundary Updated

Pending final E020 classification.

## Next Smallest Useful Experiment

Compare B0/B1/B2/B3 metrics before adding phase-add.
